#include "externalprojectpicker.h"

#include <QDir>
#include <QDirIterator>
#include <QGuiApplication>
#include <QWindow>
#include <QDebug>
#include <QFileDialog>

#include "raiiexec.h"

#import <Foundation/Foundation.h>

ExternalProjectPicker::ExternalProjectPicker(QObject *parent) : QObject(parent)
{
}

ExternalProjectPicker::~ExternalProjectPicker()
{
}

void ExternalProjectPicker::startImport()
{
    QFileDialog dialog;
    dialog.setFileMode(QFileDialog::Directory);
    dialog.setViewMode(QFileDialog::Detail);
    const auto res = dialog.exec();
    if (res != QDialog::Accepted)
        return;

    for (const auto& url : dialog.selectedUrls()) {
        NSError *error = nil;
        NSData *bookmarkData = [url.toNSURL()
                               bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile
                               includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
        QByteArray qBookmarkData = QByteArray::fromNSData(bookmarkData);
        emit documentSelected(qBookmarkData);
    }
}

// Open a file using the given sandbox data
QString ExternalProjectPicker::openBookmark(const QByteArray encodedData)
{
    NSData* bookmarkData = encodedData.toNSData();
    NSError* error = 0;
    BOOL stale = false;

    NSURL* url = [NSURL URLByResolvingBookmarkData:bookmarkData options:0 relativeToURL:nil bookmarkDataIsStale:&stale error:&error];
    if (!error && url)
    {
        [url startAccessingSecurityScopedResource];
        auto ret = QUrl::fromNSURL(url).toLocalFile();
        qDebug() << ret;
        return ret;
    }

    if (stale) {
        emit bookmarkStale(encodedData);
    }

    qWarning() << "Error occured opening file or path:" << error << encodedData;
    return QString();
}

bool ExternalProjectPicker::secureFile(const QString path)
{
    NSURL* url = [NSURL URLWithString:path.toNSString() relativeToURL:nil];
    if (url)
    {
        [url startAccessingSecurityScopedResource];
        auto ret = QUrl::fromNSURL(url).toLocalFile();
        qDebug() << ret;
        return true;
    }

    qWarning() << "Error occured securing external file";
    return false;
}

// Stop sandbox access
void ExternalProjectPicker::closeFile(QUrl url)
{
    NSURL* nsurl = url.toNSURL();
    if (nsurl)
    {
        [nsurl stopAccessingSecurityScopedResource];
        return;
    }

    qWarning() << "Fell through during closing of external file";
    return;
}

QString ExternalProjectPicker::getDirNameForBookmark(const QByteArray encodedData)
{
    const auto path = openBookmark(encodedData);
    if (path.isEmpty()) {
        qWarning() << "Failed to get name: path is empty";
        return QString();
    }

    QStringList parts = path.split(QDir::separator(), Qt::SkipEmptyParts);
    if (parts.isEmpty()) {
        qWarning() << "Failed to get name: path must have been empty";
        closeFile(QUrl(path));
        return QString();
    }

    closeFile(QUrl(path));
    return parts.takeLast();
}

QList<DirectoryListing> ExternalProjectPicker::listBookmarkContents(const QByteArray bookmark)
{
    const auto path = openBookmark(bookmark);
    if (path.isEmpty()) {
        qWarning() << "Failed to open bookmark";
        return QList<DirectoryListing>();
    }

    auto ret = listDirectoryContents(path, bookmark);
    closeFile(path);

    return ret;
}

QList<DirectoryListing> ExternalProjectPicker::listDirectoryContents(const QString path, const QByteArray bookmark)
{
    QList<DirectoryListing> ret;

    QStringList toSort;

    QDirIterator it(path, QDir::NoDot | QDir::AllEntries);
    while (it.hasNext()) {
        toSort << it.next();
    }

    std::sort(toSort.begin(), toSort.end());

    for (const auto& next : toSort) {
        qWarning() << next;

        DirectoryListing::ListingType type;
        QFileInfo info(next);

        if (info.isSymLink()) {
            type = DirectoryListing::Symlink;
        } else if (info.isDir()) {
            type = DirectoryListing::Directory;
        } else {
            type = DirectoryListing::File;
        }

        ret << DirectoryListing(type, next, bookmark);
    }

    return ret;
}
