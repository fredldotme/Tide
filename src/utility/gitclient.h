#ifndef GITCLIENT_H
#define GITCLIENT_H

#include <QObject>
#include <QThread>
#include <git2.h>
#include <functional>

class GitClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy MEMBER m_busy NOTIFY busyChanged)

public:
    explicit GitClient(QObject *parent = nullptr);
    ~GitClient();

public slots:
    void clone(const QString& url, const QString& name);

private:
    void run();

    bool m_busy;
    QThread m_runThread;
    std::function<void()> m_func;

signals:
    void busyChanged();
    void repoCloneStarted(const QString url, const QString name);
    void repoCloned(const QString url, const QString name);
    void error(const QString message);
    void repoExists(const QString path);

};

#endif // GITCLIENT_H
