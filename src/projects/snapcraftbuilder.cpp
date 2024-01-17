#include "snapcraftbuilder.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include <thread>

SnapcraftBuilder::SnapcraftBuilder(QObject *parent)
    : BuilderBackend{parent}, iosSystem{nullptr}, m_building(false)
{
    QObject::connect(this, &SnapcraftBuilder::projectFileChanged, this, &SnapcraftBuilder::runnableChanged);
}

void SnapcraftBuilder::setSysroot(const QString path)
{
    m_sysroot = path;
}

bool SnapcraftBuilder::loadProject(const QString path)
{
    if (!QFile::exists(path))
        return false;

    m_projectFile = path;
    emit projectFileChanged();

    return true;
}

void SnapcraftBuilder::unloadProject()
{
    m_projectFile = "";
    emit projectFileChanged();
}

void SnapcraftBuilder::clean()
{
    const auto buildPath = buildRoot() + QDir::separator() + projectName();

    QDir buildDir(buildPath);

    if (!buildDir.exists()) {
        return;
    }

    if (!buildDir.removeRecursively()) {
        qWarning() << "Failed to clean build directory" << buildPath;
    }
}

void SnapcraftBuilder::build(const bool debug, const bool aot)
{
    const auto sourcePath = projectDir();
    const auto buildPath = buildRoot() + QDir::separator() + projectName();

    QDir buildDir(buildPath);
    qDebug() << buildDir.mkpath(buildPath);

#ifndef Q_OS_LINUX
    const auto cmakePath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                           QStringLiteral("/Library/CMake");
#else
    const auto cmakePath = QStringLiteral("/snap/tide-ide/current/usr/share/cmake-3.27");
#endif
    const auto cmakeRoot = QStringLiteral("-DCMAKE_ROOT=\"%1\""
                                          " -DCMAKE_C_COMPILER=clang"
                                          " -DCMAKE_CXX_COMPILER=clang++"
                                          " -DCMAKE_SYSTEM_PROCESSOR=wasm32"
                                          " -DCMAKE_SYSROOT=\"%2\""
                                          " -DCMAKE_C_COMPILER_TARGET=wasm32-wasi-threads"
                                          " -DCMAKE_CXX_COMPILER_TARGET=wasm32-wasi-threads").arg(cmakePath, m_sysroot);
    const auto cmakeArgs = cmakeRoot + QStringLiteral(" -DCMAKE_SYSTEM_NAME=WASI -DCMAKE_SYSTEM_VERSION=1 -DCMAKE_MAKE_PROGRAM=ninja ");

    QStringList buildCommands;
    buildCommands << QStringLiteral("cmake -G Ninja -S \"%1\" %2").arg(sourcePath, cmakeArgs);
    buildCommands << QStringLiteral("ninja -j1");

    std::thread buildThread([=]() {
        m_building = true;
        emit buildingChanged();

        const auto pwd = QDir::currentPath();
        QDir::setCurrent(buildPath);
        const bool success = iosSystem->runBuildCommands(buildCommands);
        QDir::setCurrent(pwd);
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

void SnapcraftBuilder::cancel()
{
    iosSystem->killBuildCommands();
}

QString SnapcraftBuilder::runnableFile()
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

QStringList SnapcraftBuilder::includePaths()
{
    QStringList ret;
    return ret;
}

QString SnapcraftBuilder::buildRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
           QStringLiteral("/Artifacts");
}

QString SnapcraftBuilder::sourceRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
           QStringLiteral("/Projects");
}

QString SnapcraftBuilder::projectBuildRoot()
{
    QString ret = buildRoot() + QDir::separator();
    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(projectName().toUtf8());
    return ret + QString::fromUtf8(hash.result());
}

QStringList SnapcraftBuilder::sourceFiles()
{
    return QStringList();
}

bool SnapcraftBuilder::building()
{
    return m_building;
}

bool SnapcraftBuilder::isRunnable()
{
    return false;
}

QString SnapcraftBuilder::projectName()
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

QString SnapcraftBuilder::projectDir()
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
