#ifndef GITCLIENT_H
#define GITCLIENT_H

#include <QObject>
#include <QThread>
#include <QVariantMap>
#include <QVariantList>

#include <functional>

#if !defined(__EMSCRIPTEN__)
#include <git2.h>
#endif

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
        Unknown = 0,
        Current = (1 << 1),
        New = (1 << 2),
        Modified = (1 << 3),
        Deleted = (1 << 4),
        Renamed = (1 << 5),
        Typechange = (1 << 6),
        Ignored = (1 << 7),
        Conflicted = (1 << 8),
        WorkingDirectoryNew = (1 << 9),
        WorkingDirectoryDeleted = (1 << 10)
    };
    static GitFileStatus translateStatusFromBackend(const int status);
    Q_ENUM(GitFileStatus);
    Q_DECLARE_FLAGS(GitFileStatuses, GitFileStatus);
    Q_FLAG(GitFileStatuses);

    explicit GitClient(QObject *parent = nullptr);
    ~GitClient();

public slots:
    // Generic methods
    bool hasRepo(const QString& path);
    bool hasUncommitted(const QString& path);
    QString branch(const QString& path);
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
#if !defined(__EMSCRIPTEN__)
    QVariantMap gitEntryToVariant(const git_status_entry *s);
#endif

    bool m_busy;
    QString m_path;
    QVariantMap m_status;

#if !defined(__EMSCRIPTEN__)
    git_repository* m_repo;
#endif
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
