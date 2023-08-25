#include "qmakebuilder.h"

//#include "wasmrunner.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include <thread>

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
    : QObject{parent}, iosSystem{nullptr}, m_building(false)
{

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
        return;
    }

    QDir buildDir(buildDirPath);

    if (!buildDir.exists()) {
        return;
    }

    if (!buildDir.rmpath(buildDirPath)) {
        qWarning() << "Failed to clean build directory" << buildDirPath;
    }
}

void QMakeBuilder::build()
{
    const QString clangDir = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                             QStringLiteral("/Library/usr/lib/clang/14.0.0");

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

    const auto defaultFlags = QStringList{"--target=wasm32-wasi-threads", "-pthread", "-msimd128", "-D__wasi__"};
    const auto defaultLinkFlags = QStringList{"-Wl,--shared-memory"};

    QMakeParser projectParser;
    projectParser.setProjectFile(m_projectFile);

    const auto sourceDirPath = QFileInfo(m_projectFile).absolutePath();
    const auto variables = projectParser.getVariables();
    if (variables.find("SOURCES") == variables.end()) {
        const auto err = "No SOURCES found in project file.";
        qWarning() << err;
        emit buildError(err);
        return;
    }

    QStringList includeFlags;
    if (variables.find("INCLUDEPATH") != variables.end()) {
        const auto includes = variables.at("INCLUDEPATH");
        for (const auto& include : includes.values) {
            qDebug() << "Adding include:" << include;
            QString resolvedInclude = resolveDefaultVariables(include, sourceDirPath, buildDirPath);
            includeFlags << QStringLiteral("-I");
            includeFlags << QStringLiteral("\"%1\"").arg(resolvedInclude);
        }
    }

    QStringList libraryFlags;
    if (variables.find("LIBS") != variables.end()) {
        const auto libraries = variables.at("LIBS");
        for (const auto& library : libraries.values) {
            qDebug() << "Adding library:" << library;
            QString resolvedLibrary = resolveDefaultVariables(library, sourceDirPath, buildDirPath);
            libraryFlags << resolvedLibrary;
        }
    }

    QStringList defineFlags;
    if (variables.find("DEFINES") != variables.end()) {
        const auto defines = variables.at("DEFINES");
        for (const auto& define : defines.values) {
            qDebug() << "Adding define:" << define;
            defineFlags += QStringLiteral("-D%1").arg(define);
        }
    }

    QStringList cxxFlags;
    if (variables.find("QMAKE_CXXFLAGS") != variables.end()) {
        const auto defines = variables.at("QMAKE_CXXFLAGS");
        for (const auto& define : defines.values) {
            qDebug() << "Adding cxxflag:" << define;
            defineFlags += QStringLiteral("%1").arg(define);
        }
    }

    QStringList cFlags;
    if (variables.find("QMAKE_CFLAGS") != variables.end()) {
        const auto defines = variables.at("QMAKE_CFLAGS");
        for (const auto& define : defines.values) {
            qDebug() << "Adding cflag:" << define;
            defineFlags += QStringLiteral("%1").arg(define);
        }
    }

    QStringList ldFlags;
    if (variables.find("QMAKE_LDFLAGS") != variables.end()) {
        const auto flags = variables.at("QMAKE_LDFLAGS");
        for (const auto& flag : flags.values) {
            qDebug() << "Adding ldflag:" << flag;
            defineFlags += QStringLiteral("%1").arg(flag);
        }
    }

    QStringList objectsToLink;
    QList<QString> buildCommands;

    bool isCpp = false;

    // Source code contained in the project
    const auto sources = variables.at("SOURCES");

    // General compiler flags based on whether it's C or C++
    QStringList compilerFlags;
    for (const auto& source : sources.values) {
        if (!source.endsWith(".c")) {
            isCpp = true;
            break;
        }
    }

    auto compiler = QStringLiteral("clang");
    if (!isCpp) {
        compilerFlags = cFlags;
    } else {
        compilerFlags = cxxFlags;
        compiler = QStringLiteral("clang++");
    }
    
    QStringList command;
    command << compiler;
    //command << QStringLiteral("-cc1");
    //command << QStringLiteral("-fintegrated-cc1");
    //command << QStringLiteral("-fno-disable-free");
    command << QStringLiteral("--sysroot=") + m_sysroot;
    command << defaultFlags;
    if (!includeFlags.isEmpty())
        command << includeFlags;
    if (!defineFlags.isEmpty())
        command << defineFlags;
    if (!libraryFlags.isEmpty())
        command << libraryFlags;
    if (!compilerFlags.isEmpty())
        command << compilerFlags;

    for (const auto& source : sources.values) {
        QString sourceFile = resolveDefaultVariables(source, sourceDirPath, buildDirPath);

        // No PWD implies relative to source dir
        if (!sourceFile.startsWith(QDir::separator()))
            sourceFile = sourceDirPath + QDir::separator() + source;

        //const QString sourceFileName = QFileInfo(sourceFile).fileName();
        //const QString buildObject = buildDirPath + QDir::separator() + sourceFileName + ".o";
        //objectsToLink << buildObject;

        command << QStringLiteral("\"%1\"").arg(sourceFile);
    }

    command << QStringLiteral("-o");
    command << QStringLiteral("\"%1\"").arg(runnableFile());

    qDebug() << "Compile command:" << command;
    buildCommands << command;

#if 0
    QStringList objectFlags;
    for (const auto& object : objectsToLink) {
        objectFlags += QStringLiteral("\"%1\"").arg(object);
    }
    
    QStringList linkCommand;
    linkCommand << QStringLiteral("clang++");
    linkCommand << QStringLiteral("--sysroot=%1").arg(m_sysroot);

    if (!defaultLinkFlags.isEmpty())
        linkCommand << defaultLinkFlags;

    if (!objectFlags.isEmpty())
        linkCommand << objectFlags;
    if (!libraryFlags.isEmpty())
        linkCommand << libraryFlags;
    if (!ldFlags.isEmpty())
        linkCommand << ldFlags;
    linkCommand << QStringLiteral("-o") << runnableFile();

    qDebug() << "Link command:" << linkCommand;
    buildCommands << linkCommand;
#endif

    std::thread buildThread([=]() {
        m_building = true;
        emit buildingChanged();

#if 1
        const bool success = (iosSystem->runBuildCommands(buildCommands));
#else
        bool success = false;
        for (auto args : buildCommands) {
            const QString target = QStandardPaths::writableLocation(QStandardPaths::TempLocation) +
                                   QStringLiteral("/The-Sysroot/clang++");
            WasmRunner wasmRunner;
            wasmRunner.run(target, args);
            wasmRunner.waitForFinished();
            if (wasmRunner.exitCode() != 0) {
                success = false;
                break;
            }
        }
#endif
        if (success) {
            emit buildSuccess();
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

    const auto runnableFilePath = buildDirPath + QDir::separator() + target.values.front();
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
            ret << QStringLiteral("\"%1\"").arg(resolvedInclude);
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

bool QMakeBuilder::building()
{
    return m_building;
}
