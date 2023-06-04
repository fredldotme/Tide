#include "fileio.h"

#include <QFile>
#include <QDebug>
#include <QDir>

FileIo::FileIo(QObject *parent)
    : QObject{parent}
{

}

QString FileIo::readFile(const QString path)
{
    QFile file(path);
    if (!file.open(QFile::ReadOnly)) {
        qWarning() << "Failed to open file read-only";
        return "";
    }

    return QString::fromUtf8(file.readAll());
}

bool FileIo::writeFile(const QString path, const QByteArray content)
{
    QFile file(path);
    if (!file.open(QFile::ReadWrite | QFile::Truncate | QFile::Text)) {
        qWarning() << "Failed to open file read-write";
        return "";
    }

    return file.write(content) == content.size();
}

void FileIo::createDirectory(const QString path)
{
    QDir dir(path);
    if (!dir.mkpath(path)) {
        qWarning() << "Failed to create directory" << path;
        return;
    }

    dir.cdUp();
    const auto parent = dir.absolutePath();

    emit directoryCreated(path, parent);
}

void FileIo::createFile(const QString path)
{
    const auto parent = QFileInfo(path).absolutePath();
    if (writeFile(path, ""))
        emit fileCreated(path, parent);
}

void FileIo::deleteFileOrDirectory(const QString path)
{
    QFileInfo info(path);
    if (info.isDir()) {
        QDir dir(path);
        dir.removeRecursively();
    } else {
        QFile file(path);
        file.remove(path);
    }

    emit pathDeleted(path);
}
