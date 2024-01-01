#include "sysrootmanager.h"

#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QStandardPaths>

#include <microtar.h>

SysrootManager::SysrootManager(QObject *parent)
    : QObject{parent}, m_installing{false}, m_progress{0.0}
{
    QObject::connect(&m_installThread, &QThread::started, this, &SysrootManager::runInThread, Qt::DirectConnection);
}

SysrootManager::~SysrootManager()
{
    m_installThread.quit();
    m_installThread.wait(1000);
}

void SysrootManager::setProgress(const qreal value)
{
    if (m_progress == value)
        return;

    m_progress = value;
    emit progressChanged();
}

void SysrootManager::installBundledSysroot()
{
    m_installThread.start();
}

void SysrootManager::unpackTar(QString archive, QString target)
{
    mtar_t tar;
    mtar_header_t tarHeader;
    char *tarFileBuffer = nullptr;

    static const unsigned TAR_TYPE_FILE = 48;

    mtar_open(&tar, archive.toUtf8().data(), "r");
    while ((mtar_read_header(&tar, &tarHeader)) != MTAR_ENULLRECORD) {
        const auto temporaryPath = target + "/" + QString::fromUtf8(tarHeader.name, strlen(tarHeader.name));
        const auto temporaryDirPath = QFileInfo(temporaryPath).absolutePath();
        QDir temporaryDir(temporaryDirPath);

        if (!temporaryDir.exists()) {
            temporaryDir.mkpath(temporaryDirPath);
        }

        // Is the content a file?
        if (tarHeader.type == TAR_TYPE_FILE) {
            tarFileBuffer = new char[tarHeader.size];
            mtar_read_data(&tar, tarFileBuffer, tarHeader.size);

            QFile temporary(temporaryPath);
            // qDebug() << temporary.fileName();
            if (!temporary.open(QFile::WriteOnly)) {
                qWarning() << "Failed to open file for writing";
                goto next;
            }

            if (temporary.write(tarFileBuffer, tarHeader.size) != tarHeader.size) {
                qWarning() << "Failed to write size of" << tarHeader.size;
                goto next;
            }
        }

    next:
        if (tarFileBuffer) {
            delete[] tarFileBuffer;
            tarFileBuffer = nullptr;
        }
        mtar_next(&tar);
    }
    mtar_close(&tar);
}

void SysrootManager::runInThread()
{
#if defined(Q_OS_IOS)
    const auto resourcesRoot = qApp->applicationDirPath();
#elif defined(Q_OS_MACOS)
    const auto resourcesRoot = qApp->applicationDirPath() + QStringLiteral("/../Resources");
#else
    const auto resourcesRoot = qApp->applicationDirPath() + QStringLiteral("/../../resources");
#endif

    qDebug() << "Resources:" << resourcesRoot;

    const QString temporaries = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) +
                                QStringLiteral("/The-Sysroot");

    m_installing = true;
    emit installingChanged();

    const int stages = 7;
    int stage = 0;

    // Clear old temporaries
    {
        qDebug() << "Clearing old temporaries";
        QDir targetDir(temporaries);
        if (targetDir.exists())
            qDebug() << targetDir.removeRecursively();
        setProgress((qreal)stage++ / (qreal)stages);
    }

    // Unpack new temporaries
    {
        const auto archive = resourcesRoot + "/the-sysroot.tar";
        unpackTar(archive, temporaries);
        setProgress((qreal)stage++ / (qreal)stages);
    }

    // Boost
    {
        const auto archive = resourcesRoot + "/boost.tar";
        unpackTar(archive, temporaries + QStringLiteral("/Sysroot/include"));
        setProgress((qreal)stage++ / (qreal)stages);
    }

#if 0
    // CMake
    {
        const auto archive = resourcesRoot + "/cmake.tar";
        unpackTar(archive, temporaries + QStringLiteral("/CMake"));
        setProgress((qreal)stage++ / (qreal)stages);
    }
#endif

    // Python
    {
        const auto archive = resourcesRoot + "/python.tar";
        unpackTar(archive, temporaries + QStringLiteral("/Python"));
        setProgress((qreal)stage++ / (qreal)stages);
    }

    // SDL
#if 0
    {
        const auto archive = qApp->applicationDirPath() + "/SDL.tar";
        unpackTar(archive, temporaries + QStringLiteral("/Sysroot/include"));
    }
#endif

    // Clang parts
    {
        const QString source = temporaries + "/Clang";
        const QString targetRoot = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                               QStringLiteral("/Library/usr/lib/clang");
        const QString target = targetRoot + QStringLiteral("/17");

        {
            qDebug() << "Clearing old Clang area";
            QDir targetDir(targetRoot);
            if (targetDir.exists())
                qDebug() << targetDir.removeRecursively();
        }

        qDebug() << "Moving bundled Clang headers";
        QDirIterator it(source, QDir::NoDotAndDotDot | QDir::AllEntries, QDirIterator::Subdirectories);

        while (it.hasNext()) {
            const QString sourcePath = it.next();
            const QString relativePath = sourcePath.mid(source.length());
            const QString targetPath = target + relativePath;
            const QString targetDir = QFileInfo(targetPath).absolutePath();

            QDir dir(targetDir);
            if (!dir.exists()) {
                dir.mkpath(targetDir);
            }

            //qDebug() << "Moving" << relativePath << "from" << sourcePath << "to" << targetPath;
            QFile::rename(sourcePath, targetPath);
        }
        setProgress((qreal)stage++ / (qreal)stages);
    }

    // Sysroot/wasi-sdk parts
    {
        const QString source = temporaries + "/Sysroot";
        const QString target = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                               QStringLiteral("/Library/wasi-sysroot");

        qDebug() << "Clearing old sysroot area";
        QDir targetDir(target);
        if (targetDir.exists())
            qDebug() << targetDir.removeRecursively();

        qDebug() << "Moving bundled sysroot";
        QDirIterator it(source, QDir::NoDotAndDotDot | QDir::AllEntries, QDirIterator::Subdirectories);

        while (it.hasNext()) {
            const QString sourcePath = it.next();
            const QString relativePath = sourcePath.mid(source.length());
            const QString targetPath = target + relativePath;
            const QString targetDir = QFileInfo(targetPath).absolutePath();

            QDir dir(targetDir);
            if (!dir.exists()) {
                dir.mkpath(targetDir);
            }

            //qDebug() << "Moving" << relativePath << "from" << sourcePath << "to" << targetPath;
            QFile::rename(sourcePath, targetPath);
        }
        setProgress((qreal)stage++ / (qreal)stages);
    }

#if 0
    // CMake parts
    {
        const QString source = temporaries + "/CMake";
        const QString target = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                               QStringLiteral("/Library/CMake");

        qDebug() << "Clearing old CMake area";
        QDir targetDir(target);
        if (targetDir.exists())
            qDebug() << targetDir.removeRecursively();

        qDebug() << "Moving bundled CMake contents";
        QDirIterator it(source, QDir::NoDotAndDotDot | QDir::AllEntries, QDirIterator::Subdirectories);

        while (it.hasNext()) {
            const QString sourcePath = it.next();
            const QString relativePath = sourcePath.mid(source.length());
            const QString targetPath = target + relativePath;
            const QString targetDir = QFileInfo(targetPath).absolutePath();

            QDir dir(targetDir);
            if (!dir.exists()) {
                dir.mkpath(targetDir);
            }

            //qDebug() << "Moving" << relativePath << "from" << sourcePath << "to" << targetPath;
            QFile::rename(sourcePath, targetPath);
        }
        setProgress((qreal)stage++ / (qreal)stages);
    }
#endif

    // Python parts
    {
        const QString source = temporaries + "/Python";
        const QString target = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                               QStringLiteral("/Library/Python");

        qDebug() << "Clearing old Python area";
        QDir targetDir(target);
        if (targetDir.exists())
            qDebug() << targetDir.removeRecursively();

        qDebug() << "Moving bundled Python contents";
        QDirIterator it(source, QDir::NoDotAndDotDot | QDir::AllEntries, QDirIterator::Subdirectories);

        while (it.hasNext()) {
            const QString sourcePath = it.next();
            const QString relativePath = sourcePath.mid(source.length());
            const QString targetPath = target + relativePath;
            const QString targetDir = QFileInfo(targetPath).absolutePath();

            QDir dir(targetDir);
            if (!dir.exists()) {
                dir.mkpath(targetDir);
            }

            //qDebug() << "Moving" << relativePath << "from" << sourcePath << "to" << targetPath;
            QFile::rename(sourcePath, targetPath);
        }
        setProgress((qreal)stage++ / (qreal)stages);
    }

    m_installing = false;
    emit installingChanged();
}
