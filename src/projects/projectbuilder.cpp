#include "projectbuilder.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

ProjectBuilder::ProjectBuilder(QObject *parent)
    : QObject{parent}, m_iosSystem{nullptr}, m_building(false), m_activeBuilder{nullptr}
{
    QObject::connect(this, &ProjectBuilder::refreshingProperties, this, &ProjectBuilder::runnableChanged);
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
    QObject::disconnect(&m_snapcraftBuilder, nullptr, nullptr, nullptr);

    this->m_projectFile = "";
    emit projectFileChanged();
}

bool ProjectBuilder::loadProject(const QString path)
{
    if (!QFile::exists(path))
        return false;

    QObject::disconnect(&m_qmakeBuilder, nullptr, nullptr, nullptr);
    QObject::disconnect(&m_cmakeBuilder, nullptr, nullptr, nullptr);
    QObject::disconnect(&m_snapcraftBuilder, nullptr, nullptr, nullptr);

    if (path.toLower().endsWith(".pro")) {
        m_activeBuilder = &m_qmakeBuilder;
        m_qmakeBuilder.iosSystem = m_iosSystem;
        m_qmakeBuilder.setSysroot(m_sysroot);
        QObject::connect(&m_qmakeBuilder, &QMakeBuilder::commandRunnerChanged, this, &ProjectBuilder::commandRunnerChanged, Qt::DirectConnection);
    } else if (path.endsWith("/CMakeLists.txt")) {
        m_activeBuilder = &m_cmakeBuilder;
        m_cmakeBuilder.iosSystem = m_iosSystem;
        m_cmakeBuilder.setSysroot(m_sysroot);
        QObject::connect(&m_cmakeBuilder, &CMakeBuilder::commandRunnerChanged, this, &ProjectBuilder::commandRunnerChanged, Qt::DirectConnection);
    } else if (path.endsWith("/snapcraft.yaml")) {
        m_activeBuilder = &m_snapcraftBuilder;
        m_snapcraftBuilder.iosSystem = m_iosSystem;
        QObject::connect(&m_snapcraftBuilder, &SnapcraftBuilder::commandRunnerChanged, this, &ProjectBuilder::commandRunnerChanged, Qt::DirectConnection);
    } else if (path.endsWith("/clickable.json") || path.endsWith("/clickable.yaml")) {
        m_activeBuilder = &m_clickableBuilder;
        m_clickableBuilder.iosSystem = m_iosSystem;
        QObject::connect(&m_clickableBuilder, &ClickableBuilder::commandRunnerChanged, this, &ProjectBuilder::commandRunnerChanged, Qt::DirectConnection);
    }

    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return false;
    }

    QObject::connect(m_activeBuilder, &BuilderBackend::buildError, this, &ProjectBuilder::buildError, Qt::DirectConnection);
    QObject::connect(m_activeBuilder, &BuilderBackend::buildSuccess, this, &ProjectBuilder::buildSuccess, Qt::DirectConnection);
    QObject::connect(m_activeBuilder, &BuilderBackend::buildingChanged, this, &ProjectBuilder::buildingChanged, Qt::DirectConnection);
    QObject::connect(m_activeBuilder, &BuilderBackend::projectFileChanged, this, &ProjectBuilder::projectFileChanged, Qt::DirectConnection);
    QObject::connect(m_activeBuilder, &BuilderBackend::cleaned, this, &ProjectBuilder::cleaned, Qt::DirectConnection);
    QObject::connect(m_activeBuilder, &BuilderBackend::runnableChanged, this, &ProjectBuilder::runnableChanged, Qt::DirectConnection);

    // Count already loaded project as a valid operation
    if (m_projectFile == path) {
        return true;
    }

    const auto ret = m_activeBuilder->loadProject(path);
    if (!ret) {
        qWarning() << "Couldn't load project" << path;
        return false;
    }

    m_projectFile = path;
    emit projectFileChanged();
    emit sourceFilesChanged();

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

    const auto ret = m_activeBuilder->runnableFile();
    return ret;
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

QStringList ProjectBuilder::sourceFiles()
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return QStringList();
    }

    return m_activeBuilder->sourceFiles();
}

bool ProjectBuilder::building()
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return false;
    }

    return m_activeBuilder->building();
}

bool ProjectBuilder::isRunnable()
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder!";
        return false;
    }

    return m_activeBuilder->isRunnable();
}

void ProjectBuilder::reloadProperties()
{
    if (!m_activeBuilder) {
        qWarning() << "No active builder";
        return;
    }

    emit refreshingProperties();
}
