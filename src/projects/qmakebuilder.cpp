#include "qmakebuilder.h"

#include <platform/systemglue.h>

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include <thread>

#include <unistd.h>

#if __APPLE__
#include <TargetConditionals.h>
#define SUPPORT_AOT !TARGET_OS_IPHONE
#else
#define SUPPORT_AOT 0
#endif

inline static QString resolveDefaultVariables(const QString& line,
                                              const QString& sourceDir,
                                              const QString& buildDir)
{
    QString ret = line;
    ret.replace("$$PWD", sourceDir);
    ret.replace("$$OUT_PWD", buildDir);
    return ret;
}

QMakeBuilder::QMakeBuilder(QObject *parent)
    : BuilderBackend{parent}, iosSystem{nullptr}, m_building(false)
{
    QObject::connect(this, &QMakeBuilder::projectFileChanged, this, &QMakeBuilder::runnableChanged);
}

void QMakeBuilder::setSysroot(const QString path)
{
    m_sysroot = path;
}

bool QMakeBuilder::loadProject(const QString path)
{
    if (!QFile::exists(path))
        return false;

    m_projectFile = path;
    emit projectFileChanged();

    return true;
}

void QMakeBuilder::unloadProject()
{
    m_projectFile = "";
    emit projectFileChanged();
}

void QMakeBuilder::clean()
{
    const auto buildDirPath = projectBuildRoot();
    if (buildDirPath.isEmpty()) {
        const auto err = "Project's TARGET is not set.";
        qWarning() << err;
        emit cleaned();
        return;
    }

    QDir buildDir(buildDirPath);

    if (!buildDir.exists()) {
        emit cleaned();
        return;
    }

    if (!buildDir.removeRecursively()) {
        qWarning() << "Failed to clean build directory" << buildDirPath;
    }

    sync();

    emit cleaned();
}

void QMakeBuilder::build(const bool debug, const bool aot, const bool exceptions)
{
    const auto buildDirPath = projectBuildRoot();
    if (buildDirPath.isEmpty()) {
        const auto err = "Project's TARGET is not set.";
        emit buildError(err);
        return;
    }

    QDir buildDir(buildDirPath);

    if (!buildDir.exists()) {
        buildDir.mkpath(buildDirPath);
    }

    QMakeParser projectParser;
    projectParser.setProjectFile(m_projectFile);

    const auto sourceDirPath = QFileInfo(m_projectFile).absolutePath();
    const auto variables = projectParser.getVariables();

    static const auto typeApp = QStringLiteral("app");
    auto projectTemplate = typeApp;
    if (variables.find("TEMPLATE") != variables.end()) {
        if (variables.at("TEMPLATE").values.size() == 1)
            projectTemplate = variables.at("TEMPLATE").values.front();
    }

    // Hardcode, but keep dependent code paths intact for now
    const bool useThreads = true;

    const auto commonFlags = exceptions ?
        QStringLiteral(" -fwasm-exceptions ") : QStringLiteral(" -fno-exceptions ");

    auto targetTriplet = QStringLiteral("wasm32-wasi");
    if (useThreads && exceptions) {
        targetTriplet = QStringLiteral("wasm32-wasi-threads-exce");
    } else if (useThreads && !exceptions) {
        targetTriplet = QStringLiteral("wasm32-wasi-threads");
    }

    const auto threadFlags = (useThreads ?
                                  QStringLiteral(" --target=%1 -ftls-model=local-exec -pthread ").arg(targetTriplet) :
                                  QStringLiteral(" --target=%1 ").arg(targetTriplet));

    const auto defaultFlags = threadFlags;
    const auto defaultLinkFlags = threadFlags +
                                  ((projectTemplate == typeApp) ?
                                       QString() :
                                       QStringLiteral(" -Wl,--no-entry -Wl,--export-all "));

    if (variables.find("SOURCES") == variables.end()) {
        const auto err = "No SOURCES found in project file.";
        qWarning() << err;
        emit buildError(err);
        return;
    }

    QString includeFlags;
    if (variables.find("INCLUDEPATH") != variables.end()) {
        const auto includes = variables.at("INCLUDEPATH");
        for (const auto& include : includes.values) {
            qDebug() << "Adding include:" << include;
            QString resolvedInclude = resolveDefaultVariables(include, sourceDirPath, buildDirPath);
            includeFlags += QStringLiteral(" -I \"%1\" ").arg(resolvedInclude);
        }
    }

    QString libraryFlags;
    if (variables.find("LIBS") != variables.end()) {
        const auto libraries = variables.at("LIBS");
        for (const auto& library : libraries.values) {
            qDebug() << "Adding library:" << library;
            QString resolvedLibrary = resolveDefaultVariables(library, sourceDirPath, buildDirPath);
            libraryFlags += QStringLiteral(" -Wl,%1 ").arg(resolvedLibrary);
        }
    }

    QString defineFlags;
    if (variables.find("DEFINES") != variables.end()) {
        const auto defines = variables.at("DEFINES");
        for (const auto& define : defines.values) {
            qDebug() << "Adding define:" << define;
            defineFlags += QStringLiteral(" -D%1 ").arg(define);
        }
    }

    QStringList objectsToLink;
    QStringList buildCommands;

    QString cFlags;
    if (variables.find("QMAKE_CFLAGS") != variables.end()) {
        const auto flags = variables.at("QMAKE_CFLAGS");
        for (const auto& flag : flags.values) {
            qDebug() << "Adding flag:" << flag;
            QString resolvedFlag = resolveDefaultVariables(flag, sourceDirPath, buildDirPath);
            cFlags += QStringLiteral(" %1 ").arg(resolvedFlag);
        }
    }

    QString cxxFlags;
    if (variables.find("QMAKE_CXXFLAGS") != variables.end()) {
        const auto flags = variables.at("QMAKE_CXXFLAGS");
        for (const auto& flag : flags.values) {
            qDebug() << "Adding flag:" << flag;
            QString resolvedFlag = resolveDefaultVariables(flag, sourceDirPath, buildDirPath);
            cxxFlags += QStringLiteral(" %1 ").arg(resolvedFlag);
        }
    }

    const auto sources = variables.at("SOURCES");
    for (const auto& source : sources.values) {
        QString sourceFile = resolveDefaultVariables(source, sourceDirPath, buildDirPath);

        // No PWD implies relative to source dir
        if (!sourceFile.startsWith(QDir::separator()))
            sourceFile = sourceDirPath + QDir::separator() + source;

        const QString sourceFileName = QFileInfo(sourceFile).fileName();
        const QString buildObject = buildDirPath + QDir::separator() + sourceFileName + ".o";
        objectsToLink << buildObject;

        const auto compiler = source.endsWith(".c") ? QStringLiteral("clang") : QStringLiteral("clang++");
        const QString command = compiler +
                                QStringLiteral(" --sysroot=") + m_sysroot +
                                QStringLiteral(" -c ") +
                                (debug ? QStringLiteral(" -g ") : QString()) +
                                defaultFlags +
                                commonFlags +
                                includeFlags +
                                defineFlags +
                                QStringLiteral(" -o \"%1\" ").arg(buildObject) +
                                QStringLiteral(" \"%1\"").arg(sourceFile) +
                                (source.endsWith(".c") ? cFlags : cxxFlags);
        qDebug() << "Compile command:" << command;
        buildCommands << command;
    }

    QString objectFlags;
    for (const auto& object : objectsToLink) {
        objectFlags += QStringLiteral(" \"%1\" ").arg(object);
    }

    QString linkFlags;
    if (variables.find("QMAKE_LDFLAGS") != variables.end()) {
        const auto flags = variables.at("QMAKE_LDFLAGS");
        for (const auto& flag : flags.values) {
            qDebug() << "Adding flag:" << flag;
            QString resolvedFlag = resolveDefaultVariables(flag, sourceDirPath, buildDirPath);
            linkFlags += QStringLiteral(" -Wl,%1 ").arg(resolvedFlag);
        }
    }

    const auto undefinedSymbolsFile =
        useThreads ?
            QStringLiteral("%1/share/%2/undefined-symbols.txt").arg(m_sysroot, targetTriplet) :
            QStringLiteral("%1/share/%2/undefined-symbols.txt").arg(m_sysroot, targetTriplet);
    const auto undefinedSymbolsLinkFlags =
        QStringLiteral(" -Wl,--allow-undefined-file=%1 ").arg(undefinedSymbolsFile);
    const QString linkCommand = QStringLiteral("clang++") +
                                (debug ? QStringLiteral(" -g ") : QString()) +
                                QStringLiteral(" --sysroot=") + m_sysroot +
                                defaultFlags +
                                commonFlags +
                                undefinedSymbolsLinkFlags +
                                defaultLinkFlags +
                                linkFlags +
                                objectFlags +
                                libraryFlags +
                                QStringLiteral(" -o \"%1\"").arg(runnableFile());

    qDebug() << "Link command:" << linkCommand;
    buildCommands << linkCommand;

    std::thread buildThread([=]() {
        m_building = true;
        emit buildingChanged();

        const bool success = iosSystem->runBuildCommands(buildCommands);
        if (success) {
            emit buildSuccess(debug, aot);
        } else {
            emit buildError(QStringLiteral("Build failed"));
        }

        m_building = false;
        emit buildingChanged();
    });
    buildThread.detach();
}

void QMakeBuilder::cancel()
{
    iosSystem->killBuildCommands();
}

QString QMakeBuilder::runnableFile()
{
    const auto buildDirPath = projectBuildRoot();
    if (buildDirPath.isEmpty()) {
        const auto err = "Project's TARGET is not set.";
        qWarning() << err;
        return QString();
    }

    QMakeParser projectParser;
    projectParser.setProjectFile(m_projectFile);

    const auto variables = projectParser.getVariables();
    if (variables.find("TARGET") == variables.end()) {
        const auto err = "No TARGET found in project file.";
        qWarning() << err;
        return QString();
    }

    const auto target = variables.at("TARGET");
    if (target.values.empty()) {
        const auto err = "TARGET is empty";
        qWarning() << err;
        return QString();
    }

    const QString binPrefix = (!isRunnable() ? QStringLiteral("lib") : QString());
    const QString binSuffix = (!isRunnable() ? QStringLiteral(".a") : QString());

    const auto runnableFilePath = buildDirPath + QDir::separator() +
                                  binPrefix + target.values.front() + binSuffix;
    return runnableFilePath;
}

QStringList QMakeBuilder::includePaths()
{
    QStringList ret;
    QMakeParser projectParser;
    projectParser.setProjectFile(m_projectFile);

    const auto buildDirPath = projectBuildRoot();
    const auto sourceDirPath = QFileInfo(m_projectFile).absolutePath();
    const auto variables = projectParser.getVariables();

    if (variables.find("INCLUDEPATH") != variables.end()) {
        const auto includes = variables.at("INCLUDEPATH");
        for (const auto& include : includes.values) {
            qDebug() << "Include path:" << include;
            QString resolvedInclude = resolveDefaultVariables(include, sourceDirPath, buildDirPath);
            ret << resolvedInclude;
        }
    }

    return ret;
}

QString QMakeBuilder::buildRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
           QStringLiteral("/Artifacts");

}

QString QMakeBuilder::sourceRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
           QStringLiteral("/Projects");
}

QString QMakeBuilder::projectBuildRoot()
{
    QString ret = buildRoot() + QDir::separator();
    QMakeParser projectParser;
    projectParser.setProjectFile(m_projectFile);

    const auto variables = projectParser.getVariables();
    if (variables.find("TARGET") == variables.end()) {
        const auto err = "No TARGET found in project file.";
        qWarning() << err;
        return QString();
    }

    const auto target = variables.at("TARGET");
    if (target.values.empty()) {
        const auto err = "TARGET is empty";
        qWarning() << err;
        return QString();
    }

    return ret + target.values.front();
}

QStringList QMakeBuilder::sourceFiles()
{
    QStringList ret;

    const auto buildDirPath = projectBuildRoot();
    if (buildDirPath.isEmpty()) {
        const auto err = "Project's TARGET is not set.";
        emit buildError(err);
        return QStringList();
    }

    QDir buildDir(buildDirPath);
    if (!buildDir.exists()) {
        buildDir.mkpath(buildDirPath);
    }

    QMakeParser projectParser;
    projectParser.setProjectFile(m_projectFile);

    const auto sourceDirPath = QFileInfo(m_projectFile).absolutePath();
    const auto variables = projectParser.getVariables();

    if (variables.find("SOURCES") == variables.end()) {
        const auto err = "No SOURCES found in project file.";
        qWarning() << err;
        return QStringList();
    }

    const auto sources = variables.at("SOURCES");
    for (const auto& source : sources.values) {
        QString sourceFile = resolveDefaultVariables(source, sourceDirPath, buildDirPath);
        ret << sourceFile;
    }
    return ret;
}

bool QMakeBuilder::building()
{
    return m_building;
}

bool QMakeBuilder::isRunnable()
{
    // Defaults to true or rather TEMPLATE=app if not provided otherwise

    QMakeParser projectParser;
    projectParser.setProjectFile(m_projectFile);

    const auto sourceDirPath = QFileInfo(m_projectFile).absolutePath();
    const auto variables = projectParser.getVariables();

    if (variables.find("TEMPLATE") == variables.end()) {
        const auto err = "No TEMPLATE found in project file, assuming 'app'.";
        qWarning() << err;
        return true;
    }

    const auto templ = variables.at("TEMPLATE");
    return (templ.values.front() == QStringLiteral("app"));
}
