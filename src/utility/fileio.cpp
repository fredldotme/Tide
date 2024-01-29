#include "fileio.h"

#include <QFile>
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QMimeDatabase>
#include <QMimeType>

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

qint64 FileIo::fileSize(const QString path)
{
    QFileInfo file(path);
    if (!file.exists()) {
        qWarning() << "Cannot fetch size for" << path << ", doesn't exist";
        return 0;
    }
    return file.size();
}

quint64 FileIo::directoryContents(const QString path)
{
    quint64 ret = 0;

    QDir dir(path);
    if (!dir.exists()) {
        qWarning() << "Directory doesn't exist, cannot fetch content number of" << path;
        return 0;
    }

    QDirIterator it(path, QDir::AllEntries | QDir::NoDotAndDotDot, QDirIterator::NoIteratorFlags);
    while(it.hasNext()) {
        ++ret;
        it.next();
    }

    return ret;
}

bool FileIo::fileIsTextFile(const QString path)
{
    // Hello, young freshling
    if (QFileInfo(path).size() == 0) {
        return true;
    }

    QMimeDatabase db;
    QMimeType mime = db.mimeTypeForFile(path);
    return (mime.inherits("text/plain"));
}

