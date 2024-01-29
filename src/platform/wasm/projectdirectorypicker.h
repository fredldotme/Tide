#ifndef PROJECTDIRECTORYPICKER_H
#define PROJECTDIRECTORYPICKER_H

#include <QObject>
#include <QUrl>

#include "directorylisting.h"

class ProjectDirectoryPicker : public QObject
{
    Q_OBJECT
public:
    explicit ProjectDirectoryPicker(QObject *parent = nullptr);
    ~ProjectDirectoryPicker();

public slots:
    void startImport();
    QString openBookmark(const QByteArray encodedData);
    bool secureFile(const QString path);
    void closeFile(QUrl url);
    QString getDirNameForBookmark(const QByteArray encodedData);
    QList<DirectoryListing> listBookmarkContents(const QByteArray bookmark);
    QList<DirectoryListing> listDirectoryContents(const QString path, const QByteArray bookmark);

signals:
    void documentSelected(QByteArray document);
    void bookmarkStale(QByteArray document);
};

#endif // PROJECTDIRECTORYPICKER_H
