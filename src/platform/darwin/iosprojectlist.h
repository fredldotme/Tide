#ifndef IOSPROJECTLIST_H
#define IOSPROJECTLIST_H

#include <QObject>

#include "bookmarkdb.h"
#include "directorylisting.h"

class IosProjectList : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList projects READ projects NOTIFY projectsChanged CONSTANT)
    Q_PROPERTY(BookmarkDb* bookmarkDb MEMBER m_bookmarkDb NOTIFY bookmarkDbChanged)

public:
    explicit IosProjectList(QObject *parent = nullptr);

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

#endif // IOSPROJECTLIST_H
