#include "directorylisting.h"

#include <QDir>
#include <QDebug>

DirectoryListing::DirectoryListing(const ListingType type,
                                   const QString path,
                                   const QByteArray bookmark)
    : type(type), path(path), bookmark(bookmark)
{
    QStringList parts = path.split(QDir::separator(), Qt::SkipEmptyParts);
    if (parts.isEmpty()) {
        qWarning() << "Failed to get name: path must have been empty";
        name = QString();
    } else {
        name = parts.last();
    }

    qDebug() << "New directory listing: " << path << type << name;
}
