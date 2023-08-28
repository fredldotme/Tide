#include "cmakebuilder.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include <thread>

CMakeBuilder::CMakeBuilder(QObject *parent)
    : QObject{parent}, iosSystem{nullptr}, m_building(false)
{
    const auto cmakePath = qApp->applicationDirPath().toUtf8() + "/Frameworks/cmake.framework";
    qputenv("CMAKE_ROOT", cmakePath);
    qputenv("CC", "clang");
    qputenv("CXX", "clang++");
}

void CMakeBuilder::setSysroot(const QString path)
{
    m_sysroot = path;
}

bool CMakeBuilder::loadProject(const QString path)
{
    if (!QFile::exists(path))
        return false;

    m_projectFile = path;
    emit projectFileChanged();

    return true;
}

void CMakeBuilder::unloadProject()
{
    m_projectFile = "";
    emit projectFileChanged();
}

void CMakeBuilder::clean()
{
    const auto sourcePath = sourceRoot() + "/CMakeTest";
    const auto buildPath = sourcePath + "/build";

    QDir buildDir(buildPath);

    if (!buildDir.exists()) {
        return;
    }

    if (!buildDir.rmpath(buildPath)) {
        qWarning() << "Failed to clean build directory" << buildPath;
    }
}

void CMakeBuilder::build(const bool debug)
{
    const auto sourcePath = sourceRoot() + "/CMakeTest";
    const auto buildPath = sourcePath + "/build";

    QDir buildDir(buildPath);
    qDebug() << buildDir.mkpath(buildPath);

    QStringList buildCommands;
    buildCommands << QStringLiteral("cmake -G Ninja -S \"%1\" -B \"%2\"").arg(sourcePath, buildPath);
    buildCommands << QStringLiteral("ninja -j1");

    std::thread buildThread([=]() {
        m_building = true;
        emit buildingChanged();

        //const bool success = iosSystem->runBuildCommands(buildCommands, buildPath, false, false);
        const bool success = false;
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

void CMakeBuilder::cancel()
{
    iosSystem->killBuildCommands();
}

QString CMakeBuilder::runnableFile()
{
    const auto buildDirPath = projectBuildRoot();
    if (buildDirPath.isEmpty()) {
        const auto err = "Project's TARGET is not set.";
        qWarning() << err;
        return QString();
    }

    const auto runnableFilePath = buildDirPath + QDir::separator() + "CMakeTest";
    return runnableFilePath;
}

QStringList CMakeBuilder::includePaths()
{
    QStringList ret;
    return ret;
}

QString CMakeBuilder::buildRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
           QStringLiteral("/Artifacts");
}

QString CMakeBuilder::sourceRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
           QStringLiteral("/Projects");
}

QString CMakeBuilder::projectBuildRoot()
{
    QString ret = buildRoot() + QDir::separator();
    return ret + "CMakeTest";
}

bool CMakeBuilder::building()
{
    return m_building;
}
