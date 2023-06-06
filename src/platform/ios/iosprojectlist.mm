#include "iosprojectlist.h"

#include <QDirIterator>
#include <QStandardPaths>
#include <QUrl>

#include <MacTypes.h>

#import <Foundation/Foundation.h>

ProjectList::ProjectList(QObject *parent)
    : QObject{parent}, m_bookmarkDb{nullptr}
{
    QObject::connect(this, &ProjectList::bookmarkDbChanged, this, &ProjectList::projectsChanged);
    QObject::connect(this, &ProjectList::bookmarkDbChanged, this, [=](){
        QObject::connect(this->m_bookmarkDb, &BookmarkDb::bookmarksChanged, this, &ProjectList::projectsChanged);
    });
}

void ProjectList::refresh()
{
    emit projectsChanged();
}

QVariantList ProjectList::projects()
{
    QVariantList ret;

    const auto documentsRoot = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QDirIterator it(documentsRoot, QDir::NoDotAndDotDot | QDir::AllDirs);
    while (it.hasNext()) {
        const auto path = it.next();
        const auto name = path.split(QDir::separator()).last();
        QVariantMap project;
        project.insert("isBookmark", false);
        project.insert("path", path);
        project.insert("name", name);
        ret << project;
    }

    for (const auto& bookmark : m_bookmarkDb->bookmarks()) {
        QVariantMap bm;
        bm.insert("isBookmark", true);
        bm.insert("bookmark", bookmark);
        ret << bm;
    }

    return ret;
}

QList<DirectoryListing> ProjectList::listDirectoryContents(const QString path)
{
    QList<DirectoryListing> ret;
    qDebug() << "Iterating through" << path;

    QDirIterator it(path, QDir::NoDot | QDir::AllEntries);
    while (it.hasNext()) {
        const auto next = it.next();
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

        QFileInfo fileInfo(next);
        QUrl preNsUrl(fileInfo.absoluteDir().absolutePath());
        NSURL* nsurl = preNsUrl.toNSURL();

        const QByteArray bookmark = QByteArray::fromNSData([NSURL bookmarkDataWithContentsOfURL:nsurl error:nil]);
        ret << DirectoryListing(type, next, bookmark);
    }

    return ret;
}

void ProjectList::removeProject(const QString path)
{
    QDir dir(path);
    if (!dir.removeRecursively()) {
        qWarning() << "Failed to remove project";
    }

    emit projectsChanged();
}
