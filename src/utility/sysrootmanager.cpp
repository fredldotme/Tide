#include "sysrootmanager.h"

#include <QCoreApplication>
#include <QStandardPaths>
#include <QDirIterator>

SysrootManager::SysrootManager(QObject *parent)
    : QObject{parent}
{

}

void SysrootManager::installBundledSysroot()
{
    // Clang parts
    {
        const QString source = qApp->applicationDirPath() + "/Clang";
        const QString target = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                               QStringLiteral("/Library/usr/lib/clang/14.0.0");

        qDebug() << "Clearing old Clang area";
        QDir targetDir(target);
        if (targetDir.exists())
            qDebug() << targetDir.removeRecursively();

        qDebug() << "Copying bundled clang headers";
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

            qDebug() << "Copying" << relativePath << "from" << sourcePath << "to" << targetPath;
            QFile::copy(sourcePath, targetPath);
        }
    }

    // Sysroot/wasi-sdk parts
    {
        const QString source = qApp->applicationDirPath() + "/Sysroot";
        const QString target = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                               QStringLiteral("/Library/wasi-sysroot");

        qDebug() << "Clearing old sysroot area";
        QDir targetDir(target);
        if (targetDir.exists())
            qDebug() << targetDir.removeRecursively();

        qDebug() << "Copying bundled sysroot";
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

            qDebug() << "Copying" << relativePath << "from" << sourcePath << "to" << targetPath;
            QFile::copy(sourcePath, targetPath);
        }
    }
}
