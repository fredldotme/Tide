#ifndef EXTERNALPROJECTPICKER_H
#define EXTERNALPROJECTPICKER_H

#include <QObject>
#include <QUrl>

#include "directorylisting.h"

class ExternalProjectPicker : public QObject
{
    Q_OBJECT
public:
    explicit ExternalProjectPicker(QObject *parent = nullptr);
    ~ExternalProjectPicker();

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

#endif // EXTERNALPROJECTPICKER_H
