#include "fileio.h"

#include <QDebug>
#include <QFile>

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
        qWarning() << "Failed to open file read-only";
        return "";
    }

    return file.write(content) == content.size();
}
