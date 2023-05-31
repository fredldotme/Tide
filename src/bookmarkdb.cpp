#include "bookmarkdb.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QStandardPaths>

BookmarkDb::BookmarkDb(QObject *parent)
    : QObject{parent}
{
    const QStandardPaths::StandardLocation location = QStandardPaths::ConfigLocation;
    const QString dbFilePath =
        QStandardPaths::writableLocation(location)
        + QStringLiteral("/%1/projects.db").arg(qApp->applicationName());
    const QString dbName = QStringLiteral("importedProjects");

    const QFileInfo dbFileInfo(dbFilePath);
    const QDir dbDir = dbFileInfo.absoluteDir();

    if (!(dbDir.exists() || dbDir.mkpath(dbDir.absolutePath()))) {
        qWarning() << "Failed to create necessary directory" << dbDir.absolutePath();
        return;
    }

    if (QSqlDatabase::contains(dbName))
        this->m_importedProjectDb = QSqlDatabase::database(dbName);
    else
        this->m_importedProjectDb = QSqlDatabase::addDatabase("QSQLITE", dbName);
    this->m_importedProjectDb.setDatabaseName(dbFilePath);

    createDb();
}

QByteArrayList BookmarkDb::bookmarks()
{
    QByteArrayList ret;

    if (!this->m_importedProjectDb.open()) {
        qWarning() << "Failed to open imported projects database:"
                   << this->m_importedProjectDb.lastError().text();
        return QByteArrayList();
    }

    const QString existanceCheck =
        QStringLiteral("SELECT bookmark from projects;");

    QSqlQuery existanceQuery(this->m_importedProjectDb);
    existanceQuery.prepare(existanceCheck);

    const bool existanceSuccess = existanceQuery.exec();
    if (!existanceSuccess) {
        qWarning() << "Failed to query for existing project:"
                   << existanceQuery.lastError().text();
        return QByteArrayList();
    }

    qDebug() << "Number of imported projects:" << existanceQuery.record().count();
    qDebug() << existanceQuery.record();
    while(existanceQuery.next()) {
        ret.push_back(existanceQuery.value(0).toByteArray());
    }

    return ret;
}

void BookmarkDb::createDb()
{
    if (!this->m_importedProjectDb.open()) {
        qWarning() << "Failed to open imported projects database:"
                   << this->m_importedProjectDb.lastError().text();
        return;
    }

    const QString version =
        QStringLiteral("CREATE table version (versionNumber INTEGER, "
                       "PRIMARY KEY(versionNumber));");
    const QString versionInsert =
        QStringLiteral("INSERT or REPLACE INTO version "
                       "values(1);");
    const QString projects =
        QStringLiteral("CREATE table projects ("
                       "bookmark BLOB, PRIMARY KEY(bookmark));");

    const QStringList existingTables = this->m_importedProjectDb.tables();
    qDebug() << "existing tables:" << existingTables;

    if (!existingTables.contains("version")) {
        const QSqlQuery versionCreateQuery = this->m_importedProjectDb.exec(version);
        if (versionCreateQuery.lastError().type() != QSqlError::NoError) {
            qWarning() << "Failed to create version table, error:"
                       << versionCreateQuery.lastError().text();
            return;
        }
        qDebug() << versionCreateQuery.executedQuery();

        const QSqlQuery versionInsertQuery = this->m_importedProjectDb.exec(versionInsert);
        if (versionInsertQuery.lastError().type() != QSqlError::NoError) {
            qWarning() << "Failed to create version table, error:"
                       << versionInsertQuery.lastError().text();
            return;
        }
        qDebug() << versionInsertQuery.executedQuery();
    }

    if (!existingTables.contains("projects")) {
        const QSqlQuery accountsCreateQuery = this->m_importedProjectDb.exec(projects);
        if (accountsCreateQuery.lastError().type() != QSqlError::NoError) {
            qWarning() << "Failed to create projects table, error:"
                       << accountsCreateQuery.lastError().text();
            return;
        }
        qDebug() << accountsCreateQuery.executedQuery();
    }
}

bool BookmarkDb::importProject(QByteArray bookmark)
{
    if (bookmark.isEmpty())
        return false;

    if (!this->m_importedProjectDb.open()) {
        qWarning() << "Failed to open imported projects database:"
                   << this->m_importedProjectDb.lastError().text();
        return false;
    }

    const QString importQuery =
        QStringLiteral("INSERT INTO projects"
                       " (bookmark) "
                       "values(:bookmark);");

    QSqlQuery query(this->m_importedProjectDb);
    query.prepare(importQuery);
    query.bindValue(":bookmark", bookmark);

    const bool querySuccess = query.exec();
    if (!querySuccess) {
        qWarning() << "Failed to insert project:" << query.lastError().text();
        return false;
    }

    qDebug() << bookmark;
    qDebug() << "Imported project:" << query.executedQuery();

    emit bookmarksChanged();
    return true;
}

bool BookmarkDb::removeBookmark(QByteArray bookmark)
{
    const QString deleteString =
        QStringLiteral("DELETE from projects"
                       " WHERE bookmark=:bookmark");

    QSqlQuery deleteQuery(this->m_importedProjectDb);
    deleteQuery.prepare(deleteString);
    deleteQuery.bindValue(":bookmark", bookmark);

    const bool deleteSuccess = deleteQuery.exec();
    if (!deleteSuccess) {
        qWarning() << "Failed to delete project:"
                   << deleteQuery.lastError().text();
        return false;
    }

    qDebug() << deleteQuery.executedQuery();

    emit bookmarksChanged();
    return true;
}


bool BookmarkDb::bookmarkExists(QByteArray bookmark)
{
    if (bookmark.isEmpty())
        return false;

    if (!this->m_importedProjectDb.open()) {
        qWarning() << "Failed to open imported projects database:"
                   << this->m_importedProjectDb.lastError().text();
        return false;
    }

    const QString existanceCheck =
        QStringLiteral("SELECT bookmark from projects"
                       " WHERE bookmark=:bookmark");

    QSqlQuery existanceQuery(this->m_importedProjectDb);
    existanceQuery.prepare(existanceCheck);
    existanceQuery.bindValue(":bookmark", QVariant(bookmark));

    const bool existanceSuccess = existanceQuery.exec();
    if (!existanceSuccess) {
        qWarning() << "Failed to query for existing project:"
                   << existanceQuery.lastError().text();
        return false;
    }

    return existanceQuery.next();
}
