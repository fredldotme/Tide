#ifndef DEBUGGER_H
#define DEBUGGER_H

#include <QObject>
#include <QThread>

#include "utility/wasmrunner.h"
#include "platform/systemglue.h"

class Debugger : public QObject
{
    Q_OBJECT

    Q_PROPERTY(WasmRunner* runner MEMBER m_runner NOTIFY runnerChanged)
    Q_PROPERTY(SystemGlue* system MEMBER m_system NOTIFY systemChanged)

public:
    explicit Debugger(QObject *parent = nullptr);

public slots:
    void debug(const QString binary, const QStringList args);
    void runDebugSession();

private:
    QThread m_debugThread;
    WasmRunner* m_runner;
    SystemGlue* m_system;
    QString m_binary;
    QStringList m_args;
    int m_port;

signals:
    void runnerChanged();
    void systemChanged();
};

#endif // DEBUGGER_H
