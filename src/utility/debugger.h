#ifndef DEBUGGER_H
#define DEBUGGER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QThread>
#include <QTimer>
#include <QVariantMap>

#include "utility/wasmrunner.h"
#include "platform/systemglue.h"

class Debugger : public QObject
{
    Q_OBJECT

    Q_PROPERTY(WasmRunner* runner MEMBER m_runner NOTIFY runnerChanged)
    Q_PROPERTY(SystemGlue* system MEMBER m_system NOTIFY systemChanged)
    Q_PROPERTY(bool running MEMBER m_running NOTIFY runningChanged);
    Q_PROPERTY(QStringList breakpoints MEMBER m_breakpoints NOTIFY breakpointsChanged)
    Q_PROPERTY(QVariantMap values MEMBER m_values NOTIFY valuesChanged);

public:
    explicit Debugger(QObject *parent = nullptr);

public slots:
    void debug(const QString binary, const QStringList args);
    void runDebugSession();
    void addBreakpoint(const QString& breakpoint);
    void removeBreakpoint(const QString& breakpoint);
    bool hasBreakpoint(const QString& breakpoint);

    void stepIn();
    void stepOut();
    void stepOver();
    void pause();
    void cont();

    void quitDebugger();

private:
    void readOutput();
    void readError();
    void read(FILE* io);
    void writeToStdIn(const QByteArray& input);

    bool m_running;
    QThread m_debugThread;
    WasmRunner* m_runner;
    SystemGlue* m_system;
    QString m_binary;
    QStringList m_args;
    int m_port;
    StdioSpec m_comm;
    QTimer m_kea;

    QThread m_readThreadOut;
    QThread m_readThreadErr;

    QStringList m_breakpoints;
    QVariantMap m_values;

signals:
    void runnerChanged();
    void systemChanged();
    void runningChanged();
    void breakpointsChanged();
    void valuesChanged();
};

#endif // DEBUGGER_H
