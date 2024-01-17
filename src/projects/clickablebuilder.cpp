#include "clickablebuilder.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include <thread>

ClickableBuilder::ClickableBuilder(QObject *parent)
    : BuilderBackend{parent}, iosSystem{nullptr}, m_building(false)
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

void ClickableBuilder::build(const bool debug, const bool aot)
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
    const auto buildDirPath = projectBuildRoot();
    const auto runnableFilePath = buildDirPath + QDir::separator() + "out.wasm";
    return runnableFilePath;
}

QStringList ClickableBuilder::includePaths()
{
    QStringList ret;
    return ret;
}

QString ClickableBuilder::buildRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
           QStringLiteral("/Artifacts");
}

QString ClickableBuilder::sourceRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
           QStringLiteral("/Projects");
}

QString ClickableBuilder::projectBuildRoot()
{
    QString ret = buildRoot() + QDir::separator();
    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(projectName().toUtf8());
    return ret + QString::fromUtf8(hash.result());
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
    return false;
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
