#ifndef SYSROOTMANAGER_H
#define SYSROOTMANAGER_H

#include <QObject>
#include <QThread>

class SysrootManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool installing MEMBER m_installing NOTIFY installingChanged FINAL)
    Q_PROPERTY(qreal progress MEMBER m_progress NOTIFY progressChanged FINAL)

public:
    explicit SysrootManager(QObject *parent = nullptr);
    ~SysrootManager();

public slots:
    void installBundledSysroot();
    void runInThread();

private:
    void unpackTar(QString archive, QString target);
    void setProgress(const qreal value);

    bool m_installing;
    qreal m_progress;
    QThread m_installThread;

    const int stages = 9;
    int stage = 0;

signals:
    void installingChanged();
    void progressChanged();
};

#endif // SYSROOTMANAGER_H
