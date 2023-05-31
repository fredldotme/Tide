#ifndef SYSROOTMANAGER_H
#define SYSROOTMANAGER_H

#include <QObject>

class SysrootManager : public QObject
{
    Q_OBJECT
public:
    explicit SysrootManager(QObject *parent = nullptr);

public slots:
    void installBundledSysroot();

signals:

};

#endif // SYSROOTMANAGER_H
