#include "sysrootmanager.h"

#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QStandardPaths>

#include <microtar.h>

SysrootManager::SysrootManager(QObject *parent)
    : QObject{parent}
{

}

void SysrootManager::installBundledSysroot()
{
    const QString temporaries = QStandardPaths::writableLocation(QStandardPaths::TempLocation) +
                                QStringLiteral("/The-Sysroot");

    // Clear old temporaries
    {
        qDebug() << "Clearing old temporaries";
        QDir targetDir(temporaries);
        if (targetDir.exists())
            qDebug() << targetDir.removeRecursively();
    }

    // Unpack new temporaries
    {
        const auto archive = qApp->applicationDirPath() + "/the-sysroot.tar";
        mtar_t tar;
        mtar_header_t tarHeader;
        char *tarFileBuffer = nullptr;

        static const unsigned TAR_TYPE_FILE = 48;

        mtar_open(&tar, archive.toUtf8().data(), "r");
        while ((mtar_read_header(&tar, &tarHeader)) != MTAR_ENULLRECORD) {
            printf("%s (%d bytes, type %d)\n", tarHeader.name, tarHeader.size, tarHeader.type);

            const auto temporaryPath = temporaries + "/" + QString::fromUtf8(tarHeader.name, strlen(tarHeader.name));
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
                qDebug() << temporary.fileName();
                if (!temporary.open(QFile::WriteOnly)) {
                    qWarning() << "Failed to open file for writing";
                    goto next;
                }

                if (temporary.write(tarFileBuffer, tarHeader.size) != tarHeader.size) {
                    qWarning() << "Failed to write size of" << tarHeader.size;
                    goto next;
                }

                qDebug() << "Unpacked" << temporaryPath;
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

    // Clang parts
    {
        const QString source = temporaries + "/Clang";
        const QString target = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                               QStringLiteral("/Library/usr/lib/clang/14.0.0");

        qDebug() << "Clearing old Clang area";
        QDir targetDir(target);
        if (targetDir.exists())
            qDebug() << targetDir.removeRecursively();

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

            qDebug() << "Moving" << relativePath << "from" << sourcePath << "to" << targetPath;
            QFile::rename(sourcePath, targetPath);
        }
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

            qDebug() << "Moving" << relativePath << "from" << sourcePath << "to" << targetPath;
            QFile::rename(sourcePath, targetPath);
        }
    }
}
