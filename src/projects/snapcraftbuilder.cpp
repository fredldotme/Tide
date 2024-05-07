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
    const auto buildPath = projectDir();

    QDir buildDir(buildPath);

    if (!buildDir.exists()) {
        return;
    }
    // TODO: remove snaps
}

void SnapcraftBuilder::build(const bool debug, const bool aot, const bool exceptions)
{
    const auto sourcePath = projectDir();

    QStringList buildCommands;
    buildCommands << QStringLiteral("snapcraft");

    std::thread buildThread([=]() {
        m_building = true;
        emit buildingChanged();

        const auto pwd = QDir::currentPath();
        QDir::setCurrent(sourcePath);
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
    return projectDir() + QStringLiteral("/snapcraft.yaml");
}

QStringList SnapcraftBuilder::includePaths()
{
    QStringList ret;
    return ret;
}

QString SnapcraftBuilder::buildRoot()
{
    return projectDir();
}

QString SnapcraftBuilder::sourceRoot()
{
    return projectDir();
}

QString SnapcraftBuilder::projectBuildRoot()
{
    return projectDir();
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
    crumbs.takeLast(); // Remove snapcraft.yaml from crumbs

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
    crumbs.takeLast(); // Remove snapcraft.yaml from crumbs

    if (crumbs.isEmpty())
        return "";

    if (!crumbs.isEmpty() && crumbs[crumbs.length() - 1] == QStringLiteral("snap"))
        crumbs.takeLast();

    return QDir::separator() + crumbs.join(QDir::separator());
}
