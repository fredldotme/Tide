#include "cmakebuilder.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include <thread>

CMakeBuilder::CMakeBuilder(QObject *parent)
    : BuilderBackend{parent}, iosSystem{nullptr}, m_building(false)
{
#ifndef Q_OS_LINUX
    const auto cmakePath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                           QStringLiteral("/Library/CMake");
#else
    const auto cmakePath = QStringLiteral("/snap/tide-ide/current/usr/share/cmake-3.27");
#endif
    qputenv("CMAKE_ROOT", cmakePath.toUtf8());
    QObject::connect(this, &CMakeBuilder::projectFileChanged, this, &CMakeBuilder::runnableChanged);
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

    if (!buildDir.removeRecursively()) {
        qWarning() << "Failed to clean build directory" << buildPath;
    }
}

void CMakeBuilder::build(const bool debug, const bool aot, const bool exceptions)
{
    const auto sourcePath = projectDir();
    const auto buildPath = buildRoot() + QDir::separator() + projectName();

    QDir buildDir(buildPath);
    qDebug() << buildDir.mkpath(buildPath);

#if defined(Q_OS_MACOS)
    const auto cmakePath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                           QStringLiteral("/Library/CMake");
    const auto cmakeBinPath = QCoreApplication::applicationDirPath() + QStringLiteral("/");
#elif defined(Q_OS_IOS)
    const auto cmakePath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                           QStringLiteral("/Library/CMake");
    const auto cmakeBinPath = QStringLiteral("/usr/bin/");
#elif defined(Q_OS_LINUX)
    const auto cmakePath = QStringLiteral("/snap/tide-ide/current/usr/share/cmake-3.27");
    const auto cmakeBinPath = QStringLiteral("");
#else
#error No cmake path set yet!
#endif
    const auto cmakeRoot = QStringLiteral("-DCMAKE_ROOT=\"%1\""
                                          " -DCMAKE_C_COMPILER=\"%2/clang\""
                                          " -DCMAKE_CXX_COMPILER=\"%2/clang++\""
                                          " -DCMAKE_ASM_COMPILER=\"%2/clang\""
                                          " -DCMAKE_AR=\"%2/llvm-ar\""
                                          " -DCMAKE_RANLIB=\"%2/llvm-ranlib\""
                                          " -DCMAKE_SYSTEM_PROCESSOR=wasm32"
                                          " -DCMAKE_SYSROOT=\"%3\""
                                          " -DCMAKE_C_COMPILER_TARGET=wasm32-wasi-threads"
                                          " -DCMAKE_CXX_COMPILER_TARGET=wasm32-wasi-threads").arg(cmakePath, cmakeBinPath, m_sysroot);
    const auto cmakeArgs = cmakeRoot + QStringLiteral(" -DCMAKE_SYSTEM_NAME=WASI -DCMAKE_SYSTEM_VERSION=1 -DCMAKE_MAKE_PROGRAM=%1ninja ").arg(cmakeBinPath);

    QStringList buildCommands;
    buildCommands << QStringLiteral("%1cmake -G Ninja -S \"%2\" -B \"%3\" %4").arg(cmakeBinPath, sourcePath, buildPath, cmakeArgs);
    buildCommands << QStringLiteral("%1ninja -C \"%2\" -j1").arg(cmakeBinPath, buildPath);

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

bool CMakeBuilder::isRunnable()
{
    return false;
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
