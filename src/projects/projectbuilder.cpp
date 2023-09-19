#include "projectbuilder.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

ProjectBuilder::ProjectBuilder(QObject *parent)
    : QObject{parent}, m_iosSystem{nullptr}, m_building(false), m_activeBuilder{nullptr}
{
}

void ProjectBuilder::setSysroot(const QString path)
{
    m_sysroot = path;
}

void ProjectBuilder::unloadProject()
{
    if (m_activeBuilder)
        m_activeBuilder->unloadProject();

    QObject::disconnect(&m_qmakeBuilder, nullptr, nullptr, nullptr);
    QObject::disconnect(&m_cmakeBuilder, nullptr, nullptr, nullptr);

    this->m_projectFile = "";
    emit projectFileChanged();
}

bool ProjectBuilder::loadProject(const QString path)
{
    if (!QFile::exists(path))
        return false;

    QObject::disconnect(&m_qmakeBuilder, nullptr, nullptr, nullptr);
    QObject::disconnect(&m_cmakeBuilder, nullptr, nullptr, nullptr);

    if (path.toLower().endsWith(".pro")) {
        m_activeBuilder = &m_qmakeBuilder;
        m_qmakeBuilder.iosSystem = m_iosSystem;
        m_qmakeBuilder.setSysroot(m_sysroot);
        QObject::connect(&m_qmakeBuilder, &QMakeBuilder::buildError, this, &ProjectBuilder::buildError, Qt::DirectConnection);
        QObject::connect(&m_qmakeBuilder, &QMakeBuilder::buildSuccess, this, &ProjectBuilder::buildSuccess, Qt::DirectConnection);
        QObject::connect(&m_qmakeBuilder, &QMakeBuilder::buildingChanged, this, &ProjectBuilder::buildingChanged, Qt::DirectConnection);
        QObject::connect(&m_qmakeBuilder, &QMakeBuilder::projectFileChanged, this, &ProjectBuilder::projectFileChanged, Qt::DirectConnection);
        QObject::connect(&m_qmakeBuilder, &QMakeBuilder::commandRunnerChanged, this, &ProjectBuilder::commandRunnerChanged, Qt::DirectConnection);
    } else if (path.endsWith("/CMakeLists.txt")) {
        m_activeBuilder = &m_cmakeBuilder;
        m_cmakeBuilder.iosSystem = m_iosSystem;
        m_cmakeBuilder.setSysroot(m_sysroot);
        QObject::connect(&m_cmakeBuilder, &CMakeBuilder::buildError, this, &ProjectBuilder::buildError, Qt::DirectConnection);
        QObject::connect(&m_cmakeBuilder, &CMakeBuilder::buildSuccess, this, &ProjectBuilder::buildSuccess, Qt::DirectConnection);
        QObject::connect(&m_cmakeBuilder, &CMakeBuilder::buildingChanged, this, &ProjectBuilder::buildingChanged, Qt::DirectConnection);
        QObject::connect(&m_cmakeBuilder, &CMakeBuilder::projectFileChanged, this, &ProjectBuilder::projectFileChanged, Qt::DirectConnection);
        QObject::connect(&m_cmakeBuilder, &CMakeBuilder::commandRunnerChanged, this, &ProjectBuilder::commandRunnerChanged, Qt::DirectConnection);
    }

    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return false;
    }

    const auto ret = m_activeBuilder->loadProject(path);

    if (!ret) {
        qWarning() << "Couldn't load project" << path;
        return false;
    }

    m_projectFile = path;
    emit projectFileChanged();

    return ret;
}

void ProjectBuilder::clean()
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return;
    }

    m_activeBuilder->clean();
}

void ProjectBuilder::build(const bool debug, const bool aot)
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return;
    }

    m_activeBuilder->build(debug, aot);
}

void ProjectBuilder::cancel()
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return;
    }

    m_activeBuilder->cancel();
}

QString ProjectBuilder::runnableFile()
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return QString();
    }

    return m_activeBuilder->runnableFile();
}

QStringList ProjectBuilder::includePaths()
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return QStringList{};
    }

    return m_activeBuilder->includePaths();
}

QString ProjectBuilder::buildRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
           QStringLiteral("/Artifacts");

}

QString ProjectBuilder::sourceRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
           QStringLiteral("/Projects");
}

QString ProjectBuilder::projectBuildRoot()
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return QString();
    }

    return m_activeBuilder->projectBuildRoot();
}

bool ProjectBuilder::building()
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return false;
    }

    return m_activeBuilder->building();
}
