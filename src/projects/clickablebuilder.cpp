#include "clickablebuilder.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include <thread>

ClickableBuilder::ClickableBuilder(QObject *parent)
    : BuilderBackend{parent}, iosSystem{nullptr}, m_building(false), m_running(false)
{
    QObject::connect(this, &ClickableBuilder::projectFileChanged, this, &ClickableBuilder::runnableChanged);
}

void ClickableBuilder::setSysroot(const QString path)
{
    m_sysroot = path;
}

bool ClickableBuilder::loadProject(const QString path)
{
    if (!QFile::exists(path))
        return false;

    m_projectFile = path;
    emit projectFileChanged();

    return true;
}

void ClickableBuilder::unloadProject()
{
    m_projectFile = "";
    emit projectFileChanged();
}

void ClickableBuilder::clean()
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

void ClickableBuilder::build(const bool debug, const bool aot, const bool exceptions)
{
    const auto sourcePath = projectDir();
    const auto buildPath = buildRoot() + QDir::separator() + projectName();

    QDir buildDir(buildPath);
    qDebug() << buildDir.mkpath(buildPath);

    QStringList buildCommands;
    buildCommands << QStringLiteral("clickable build");

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

void ClickableBuilder::cancel()
{
    iosSystem->killBuildCommands();
}

QString ClickableBuilder::runnableFile()
{
    return projectDir() + QStringLiteral("/snapcraft.yaml");
}

QStringList ClickableBuilder::includePaths()
{
    QStringList ret;
    return ret;
}

QString ClickableBuilder::buildRoot()
{
    return projectDir();
}

QString ClickableBuilder::sourceRoot()
{
    return projectDir();
}

QString ClickableBuilder::projectBuildRoot()
{
    return projectDir();
}

QStringList ClickableBuilder::sourceFiles()
{
    return QStringList();
}

bool ClickableBuilder::building()
{
    return m_building;
}

bool ClickableBuilder::isRunnable()
{
    return true;
}

bool ClickableBuilder::hasRunCommand()
{
    return true;
}

void ClickableBuilder::run()
{
    const auto sourcePath = projectDir();
    const auto buildPath = buildRoot() + QDir::separator() + projectName();

    QDir buildDir(buildPath);
    qDebug() << buildDir.mkpath(buildPath);

    QString optionalNvidia;
    if (QFile::exists("/dev/nvidia0")) {
        optionalNvidia = QStringLiteral("--nvidia");
    }

    QStringList startCommands;
    startCommands << (QStringLiteral("clickable desktop ") + optionalNvidia);

    std::thread buildThread([=]() {
        m_running = true;
        emit runningChanged();

        const auto pwd = QDir::currentPath();
        QDir::setCurrent(buildPath);
        const bool success = iosSystem->runBuildCommands(startCommands);
        QDir::setCurrent(pwd);
        /*if (success) {
            emit buildSuccess(debug, aot);
        } else {
            emit buildError(QStringLiteral("Build failed"));
        }*/

        m_running = false;
        emit runningChanged();
    });
    buildThread.detach();
}

bool ClickableBuilder::isRunning()
{
    return m_running;
}

QString ClickableBuilder::projectName()
{
    if (!m_projectFile.contains(QDir::separator())) {
        return "";
    }

    auto crumbs = m_projectFile.split(QDir::separator(), Qt::SkipEmptyParts);
    crumbs.takeLast(); // Remove clickable.{yaml,json} from crumbs

    if (crumbs.isEmpty())
        return "";

    return crumbs.last();
}

QString ClickableBuilder::projectDir()
{
    if (!m_projectFile.contains(QDir::separator())) {
        return "";
    }

    auto crumbs = m_projectFile.split(QDir::separator(), Qt::SkipEmptyParts);
    crumbs.takeLast(); // Remove clickable.{yaml,json} from crumbs

    if (crumbs.isEmpty())
        return "";

    return QDir::separator() + crumbs.join(QDir::separator());
}
