#ifndef BOOKMARKDB_H
#define BOOKMARKDB_H

#include <QObject>
#include <QByteArray>
#include <QSqlDatabase>

class BookmarkDb : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QByteArrayList bookmarks READ bookmarks NOTIFY bookmarksChanged)
public:
    explicit BookmarkDb(QObject *parent = nullptr);

public slots:
    bool importProject(QByteArray bookmark);
    bool removeBookmark(QByteArray bookmark);
    bool bookmarkExists(QByteArray bookmark);
    QByteArrayList bookmarks();

private:
    void createDb();

    QSqlDatabase m_importedProjectDb;

signals:
    void bookmarksChanged();

};

#endif // BOOKMARKDB_H
