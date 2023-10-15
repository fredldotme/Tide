#ifndef GITCLIENT_H
#define GITCLIENT_H

#include <QObject>
#include <QThread>
#include <QVariantMap>

#include <functional>

#include <git2.h>

class GitClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy MEMBER m_busy NOTIFY busyChanged)
    Q_PROPERTY(QString path MEMBER m_path NOTIFY pathChanged)
    Q_PROPERTY(QVariantMap status MEMBER m_status NOTIFY statusChanged)
    Q_PROPERTY(QStringList stagedFiles MEMBER m_stagedFiles NOTIFY stagedFilesChanged);
    Q_PROPERTY(QStringList untrackedFiles MEMBER m_untrackedFiles NOTIFY untrackedFilesChanged);

public:
    explicit GitClient(QObject *parent = nullptr);
    ~GitClient();

public slots:
    bool hasRepo(const QString& path);
    void clone(const QString& url, const QString& name);
    void stage(const QString& path);
    void unstage(const QString& path);
    void refreshStatus();
    QVariantList logs(const QString branch);

private:
    void refreshFileState();

    bool m_busy;
    QString m_path;
    QVariantMap m_status;
    git_repository* m_repo;
    QStringList m_stagedFiles;
    QStringList m_untrackedFiles;

signals:
    void pathChanged();
    void statusChanged();
    void busyChanged();
    void repoOpened(const QString path);
    void repoCloneStarted(const QString url, const QString name);
    void repoCloned(const QString url, const QString name);
    void error(const QString message);
    void repoExists(const QString path, const QString name);
    void stagedFilesChanged();
    void untrackedFilesChanged();
};

#endif // GITCLIENT_H
