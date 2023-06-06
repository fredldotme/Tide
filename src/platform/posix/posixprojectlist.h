#ifndef POSIXPROJECTLIST_H
#define POSIXPROJECTLIST_H

#include <QObject>

#include "bookmarkdb.h"

class PosixProjectList : public QObject
{
    Q_OBJECT
    Q_PROPERTY(BookmarkDb* bookmarkDb MEMBER m_bookmarkDb NOTIFY bookmarkDbChanged)
public:
    explicit PosixProjectList(QObject *parent = nullptr);

private:
    BookmarkDb* m_bookmarkDb;

signals:
    void bookmarkDbChanged();

};

#endif // POSIXPROJECTLIST_H
