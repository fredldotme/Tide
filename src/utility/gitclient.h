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

public:
    explicit GitClient(QObject *parent = nullptr);
    ~GitClient();

public slots:
    void clone(const QString& url, const QString& name);
    void refreshStatus();
    QVariantList logs(const QString branch);

private:
    bool m_busy;
    QString m_path;
    QVariantMap m_status;
    git_repository* m_repo;

signals:
    void pathChanged();
    void statusChanged();
    void busyChanged();
    void repoOpened(const QString path);
    void repoCloneStarted(const QString url, const QString name);
    void repoCloned(const QString url, const QString name);
    void error(const QString message);
    void repoExists(const QString path);
};

#endif // GITCLIENT_H
