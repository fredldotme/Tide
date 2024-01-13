#ifndef POSIXPROJECTLIST_H
#define POSIXPROJECTLIST_H

#include <QObject>

#include "bookmarkdb.h"
#include "directorylisting.h"

class PosixProjectList : public QObject
{
    Q_OBJECT
    Q_PROPERTY(BookmarkDb* bookmarkDb MEMBER m_bookmarkDb NOTIFY bookmarkDbChanged)
    Q_PROPERTY(QVariantList projects READ projects NOTIFY projectsChanged CONSTANT)

public:
    explicit PosixProjectList(QObject *parent = nullptr);

    QVariantList projects();

public slots:
    QList<DirectoryListing> listDirectoryContents(const QString path);
    void removeProject(const QString path);
    void refresh();

private:
    BookmarkDb* m_bookmarkDb;

signals:
    void projectsChanged();
    void bookmarkDbChanged();

};

#endif // POSIXPROJECTLIST_H
