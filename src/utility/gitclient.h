#ifndef GITCLIENT_H
#define GITCLIENT_H

#include <QObject>
#include <QThread>
#include <QVariantMap>
#include <QVariantList>

#include <functional>

#include <git2.h>

class GitClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy MEMBER m_busy NOTIFY busyChanged)
    Q_PROPERTY(QString path MEMBER m_path NOTIFY pathChanged)
    Q_PROPERTY(QVariantMap status MEMBER m_status NOTIFY statusChanged CONSTANT)
    Q_PROPERTY(QVariantList files MEMBER m_files NOTIFY filesChanged CONSTANT);
    Q_PROPERTY(bool hasStagedFiles MEMBER m_hasStagedFiles NOTIFY hasStagedFilesChanged CONSTANT)
    Q_PROPERTY(bool hasCommittable READ hasCommittable NOTIFY hasCommittableChanged CONSTANT)

public:
    enum GitFileStatus {
        Current = GIT_STATUS_CURRENT,
        New = GIT_STATUS_INDEX_NEW,
        Modified = GIT_STATUS_INDEX_MODIFIED,
        Deleted = GIT_STATUS_INDEX_DELETED,
        Renamed = GIT_STATUS_INDEX_RENAMED,
        Typechange = GIT_STATUS_INDEX_TYPECHANGE,
        Ignored = GIT_STATUS_IGNORED,
        Conflicted = GIT_STATUS_CONFLICTED,
        WorkingDirectoryNew = GIT_STATUS_WT_NEW,
        WorkingDirectoryDeleted = GIT_STATUS_WT_DELETED
    };
    Q_ENUM(GitFileStatus);
    Q_DECLARE_FLAGS(GitFileStatuses, GitFileStatus);
    Q_FLAG(GitFileStatuses);

    explicit GitClient(QObject *parent = nullptr);
    ~GitClient();

public slots:
    // Generic methods
    bool hasRepo(const QString& path);
    void clone(const QString& url, const QString& name);

    // Methods working on a specifically selected repository
    bool hasCommittable();
    void resetStage();
    void stage(const QString& path);
    void unstage(const QString& path);
    void refreshStatus();
    void commit(const QString& summary, const QString& body);
    QVariantList logs(const QString branch);

private:
    void refreshStage();
    QVariantMap gitEntryToVariant(const git_status_entry *s);

    bool m_busy;
    QString m_path;
    QVariantMap m_status;
    git_repository* m_repo;
    QVariantList m_files;
    bool m_hasStagedFiles;

signals:
    void pathChanged();
    void statusChanged();
    void busyChanged();
    void repoOpened(const QString path);
    void repoCloneStarted(const QString url, const QString name);
    void repoCloned(const QString url, const QString name);
    void error(const QString message);
    void repoExists(const QString path, const QString name);
    void filesChanged();
    void hasCommittableChanged();
    void hasStagedFilesChanged();
};

#endif // GITCLIENT_H
