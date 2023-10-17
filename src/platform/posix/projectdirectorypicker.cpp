#include "projectdirectorypicker.h"

#include <QDir>
#include <QDirIterator>
#include <QGuiApplication>
#include <QWindow>
#include <QDebug>
#include <QFileDialog>
#include <QStringList>
#include <QUrl>

ProjectDirectoryPicker::ProjectDirectoryPicker(QObject *parent) : QObject(parent)
{
}

ProjectDirectoryPicker::~ProjectDirectoryPicker()
{
}

void ProjectDirectoryPicker::startImport()
{
    QFileDialog dialog;
    dialog.setFileMode(QFileDialog::Directory);
    dialog.setViewMode(QFileDialog::Detail);
    dialog.exec();

    for (const auto& url : dialog.selectedUrls()) {
        emit documentSelected(url.toEncoded());
    }
}

QString ProjectDirectoryPicker::openBookmark(const QByteArray encodedData)
{
    const auto ret = QUrl::fromEncoded(encodedData).toString();

    if (!QDir(ret).exists()) {
        emit bookmarkStale(encodedData);
        return QString();
    }

    return ret;
}

bool ProjectDirectoryPicker::secureFile(const QString path)
{
    return true;
}

// Stop sandbox access
void ProjectDirectoryPicker::closeFile(QUrl url)
{
    return;
}

QString ProjectDirectoryPicker::getDirNameForBookmark(const QByteArray encodedData)
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

QList<DirectoryListing> ProjectDirectoryPicker::listBookmarkContents(const QByteArray bookmark)
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

QList<DirectoryListing> ProjectDirectoryPicker::listDirectoryContents(const QString path, const QByteArray bookmark)
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
