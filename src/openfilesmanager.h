#ifndef OPENFILESMANAGER_H
#define OPENFILESMANAGER_H

#include <QObject>
#include <QVariant>
#include <QVariantList>

#include "directorylisting.h"

class OpenFilesManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList files READ files NOTIFY filesChanged)
public:
    explicit OpenFilesManager(QObject *parent = nullptr);

public slots:
    void push(DirectoryListing listing);
    void close(DirectoryListing listing);
    void closeAllByBookmark(QByteArray bookmark);

private:
    QVariantList files();
    QList<DirectoryListing> m_files;

signals:
    void filesChanged();
    void closingFile(const DirectoryListing file);
};

#endif // OPENFILESMANAGER_H
