#include "posixprojectlist.h"

#include <QDirIterator>
#include <QStandardPaths>
#include <QUrl>

PosixProjectList::PosixProjectList(QObject *parent)
    : QObject{parent}, m_bookmarkDb{nullptr}
{
    QObject::connect(this, &PosixProjectList::bookmarkDbChanged, this, &PosixProjectList::projectsChanged);
    QObject::connect(this, &PosixProjectList::bookmarkDbChanged, this, [=](){
        QObject::connect(this->m_bookmarkDb, &BookmarkDb::bookmarksChanged, this, &PosixProjectList::projectsChanged);
    });
}


void PosixProjectList::refresh()
{
    emit projectsChanged();
}

QVariantList PosixProjectList::projects()
{
    QVariantList ret;

    const auto documentsRoot = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + QStringLiteral("/Projects");
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

    for (const auto& bookmarkData : m_bookmarkDb->bookmarks()) {
        qDebug() << "Bookmark:" << bookmarkData;
        QVariantMap bm;
        QString path;
        QString name;
        QString bookmark = bookmarkData;

        QStringList splitPath = bookmark.split(QDir::separator(), Qt::SkipEmptyParts);
        name = splitPath.last();
        path = bookmark.left(bookmark.length());

        bm.insert("isBookmark", true);
        bm.insert("bookmark", bookmark);
        bm.insert("path", path);
        bm.insert("name", name);
        ret << bm;
    }

    for (int i = 0; i < ret.length(); i++) {
        int swaps = 0;
        for (auto rit = ret.begin(); rit != (ret.end() - 1); rit++) {
            auto left = (rit);
            auto right = (rit + 1);

            const auto leftName = left->toMap().value("name").toString();
            const auto rightName = right->toMap().value("name").toString();
            if (QString::compare(leftName, rightName, Qt::CaseInsensitive) > 0) {
                std::iter_swap(left, right);
                ++swaps;
            }
        }
        if (swaps == 0)
            break;
    }

    return ret;
}

QList<DirectoryListing> PosixProjectList::listDirectoryContents(const QString path)
{
    QList<DirectoryListing> ret;
    qDebug() << "Iterating through" << path;

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

        QFileInfo fileInfo(next);
        QUrl preUrl(fileInfo.absoluteDir().absolutePath());

        const QByteArray bookmark = preUrl.toLocalFile().toUtf8();
        ret << DirectoryListing(type, next, bookmark);
    }

    return ret;
}

void PosixProjectList::removeProject(const QString path)
{
    QDir dir(path);
    if (!dir.removeRecursively()) {
        qWarning() << "Failed to remove project";
    }

    emit projectsChanged();
}
