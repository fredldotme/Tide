#include "cmakebuilder.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include <thread>

CMakeBuilder::CMakeBuilder(QObject *parent)
    : QObject{parent}, iosSystem{nullptr}, m_building(false)
{
    const auto cmakePath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                           QStringLiteral("/Library/CMake");
    qputenv("CMAKE_ROOT", cmakePath.toUtf8());
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
    const auto buildPath = buildRoot() + QDir::separator() + projectName();

    QDir buildDir(buildPath);

    if (!buildDir.exists()) {
        return;
    }

    if (!buildDir.rmpath(buildPath)) {
        qWarning() << "Failed to clean build directory" << buildPath;
    }
}

void CMakeBuilder::build(const bool debug, const bool aot)
{
    const auto sourcePath = projectDir();
    const auto buildPath = buildRoot() + QDir::separator() + projectName();

    QDir buildDir(buildPath);
    qDebug() << buildDir.mkpath(buildPath);

    const auto cmakeArgs = QStringLiteral("-DCMAKE_SYSTEM_NAME=WASI -DCMAKE_SYSTEM_VERSION=1 -DCMAKE_SYSTEM_PROCESSOR=wasm32 -DCMAKE_MAKE_PROGRAM=ninja");

    QStringList buildCommands;
    buildCommands << QStringLiteral("cmake -G Ninja -S \"%1\" -B \"%2\" %3").arg(sourcePath, buildPath, cmakeArgs);
    buildCommands << QStringLiteral("ninja -j1 -C \"%1\"").arg(buildPath);

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

    const auto runnableFilePath = buildDirPath + QDir::separator() + "out.wasm";
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
    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(projectName().toUtf8());
    return ret + QString::fromUtf8(hash.result());
}

QStringList CMakeBuilder::sourceFiles()
{
    return QStringList();
}

bool CMakeBuilder::building()
{
    return m_building;
}

QString CMakeBuilder::projectName()
{
    if (!m_projectFile.contains(QDir::separator())) {
        return "";
    }

    auto crumbs = m_projectFile.split(QDir::separator(), Qt::SkipEmptyParts);
    crumbs.takeLast(); // Remove CMakeLists.txt from crumbs

    if (crumbs.isEmpty())
        return "";

    return crumbs.last();
}

QString CMakeBuilder::projectDir()
{
    if (!m_projectFile.contains(QDir::separator())) {
        return "";
    }

    auto crumbs = m_projectFile.split(QDir::separator(), Qt::SkipEmptyParts);
    crumbs.takeLast(); // Remove CMakeLists.txt from crumbs

    if (crumbs.isEmpty())
        return "";

    return QDir::separator() + crumbs.join(QDir::separator());
}
