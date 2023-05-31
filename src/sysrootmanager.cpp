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
    const QString source = qApp->applicationDirPath() + "/Sysroot";
    const QString target = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                           QStringLiteral("/Library/usr/lib/clang/14.0.0");

    QDirIterator it(source, QDir::NoDotAndDotDot | QDir::AllEntries, QDirIterator::Subdirectories);

    qDebug() << "Copying bundled sysroot";

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
