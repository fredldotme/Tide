#include "projectbuilder.h"

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

ProjectBuilder::ProjectBuilder(QObject *parent)
    : QObject{parent}, m_iosSystem{nullptr}, m_building(false)
{

}

void ProjectBuilder::setSysroot(const QString path)
{
    m_sysroot = path;
}

bool ProjectBuilder::loadProject(const QString path)
{
    if (!QFile::exists(path))
        return false;

    m_projectFile = path;
    return true;
}

void ProjectBuilder::clean()
{
    const auto buildDirPath = buildRoot() + "/" + hash();
    QDir buildDir(buildDirPath);

    if (!buildDir.exists()) {
        return;
    }

    if (!buildDir.rmpath(buildDirPath)) {
        qWarning() << "Failed to clean build directory" << buildDirPath;
    }
}

void ProjectBuilder::build()
{
    const auto buildDirPath = buildRoot() + "/" + hash();
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
                            objectFlags +
                            libraryFlags +
                            QStringLiteral(" -o %1").arg(runnableFile());

    qDebug() << "Link command:" << linkCommand;
    buildCommands << linkCommand;

    std::thread buildThread([=]() {
        m_building = true;
        emit buildingChanged();

        const bool success = m_iosSystem->runBuildCommands(buildCommands);
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

void ProjectBuilder::cancel()
{
    m_iosSystem->killBuildCommands();
}

QString ProjectBuilder::runnableFile()
{
    const auto buildDirPath = buildRoot() + QDir::separator() + hash();
    const auto runnableFilePath = buildDirPath + QDir::separator() + "a.out";
    return runnableFilePath;
}

QStringList ProjectBuilder::includePaths()
{
    QStringList ret;
    QMakeParser projectParser;
    projectParser.setProjectFile(m_projectFile);

    const auto buildDirPath = buildRoot() + "/" + hash();
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

QString ProjectBuilder::buildRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/build");
}

QString ProjectBuilder::hash()
{
    return QCryptographicHash::hash(m_projectFile.toUtf8(), QCryptographicHash::Sha256).toHex();
}
