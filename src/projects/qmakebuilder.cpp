#include "qmakebuilder.h"

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

    const auto defaultFlags = QStringLiteral(" -Wl,--shared-memory -pthread ");

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
            libraryFlags += QStringLiteral(" %1 ").arg(resolvedLibrary);
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
                                QStringLiteral(" -c") +
                                defaultFlags +
                                includeFlags +
                                defineFlags +
                                libraryFlags +
                                QStringLiteral(" -o %1 ").arg(buildObject) +
                                QStringLiteral(" \"%1\"").arg(sourceFile);
        qDebug() << "Compile command:" << command;
        buildCommands << command;
    }

    QString objectFlags;
    for (const auto& object : objectsToLink) {
        objectFlags += QStringLiteral(" \"%1\" ").arg(object);
    }

    const QString linkCommand = QStringLiteral("clang++") +
                                QStringLiteral(" --sysroot=") + m_sysroot +
                                defaultFlags +
                                objectFlags +
                                libraryFlags +
                                QStringLiteral(" -o %1").arg(runnableFile());

    qDebug() << "Link command:" << linkCommand;
    buildCommands << linkCommand;

    std::thread buildThread([=]() {
        m_building = true;
        emit buildingChanged();

        const bool success = iosSystem->runBuildCommands(buildCommands, "", false, true);
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
