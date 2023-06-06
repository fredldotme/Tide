#ifndef DIRECTORYLISTING_H
#define DIRECTORYLISTING_H

#include <QObject>

class DirectoryListing
{
    Q_GADGET

public:
    enum ListingType {
        Unknown = 0,
        Directory,
        File,
        Symlink
    };
    Q_ENUMS(ListingType)

private:
    Q_PROPERTY(ListingType type MEMBER type)
    Q_PROPERTY(QString path MEMBER path)
    Q_PROPERTY(QString name MEMBER name)
    Q_PROPERTY(QByteArray bookmark MEMBER bookmark)

public:
    explicit DirectoryListing(const ListingType type = Unknown,
                              const QString path = "",
                              const QByteArray bookmark = "");

    ListingType type;
    QString path;
    QString name;
    QByteArray bookmark;
};

Q_DECLARE_METATYPE(DirectoryListing)

#endif // DIRECTORYLISTING_H
