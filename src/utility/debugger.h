#ifndef DEBUGGER_H
#define DEBUGGER_H

#include <QObject>
#include <QMutex>
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

    Q_PROPERTY(WasmRunner* runner READ runner WRITE setRunner NOTIFY runnerChanged)
    Q_PROPERTY(SystemGlue* system READ system WRITE setSystem NOTIFY systemChanged)
    Q_PROPERTY(bool running MEMBER m_running NOTIFY runningChanged);
    Q_PROPERTY(bool paused MEMBER m_processPaused NOTIFY processPausedChanged);
    Q_PROPERTY(QStringList breakpoints MEMBER m_breakpoints NOTIFY breakpointsChanged)
    Q_PROPERTY(QVariantList backtrace MEMBER m_backtrace NOTIFY backtraceChanged)
    Q_PROPERTY(QVariantList values MEMBER m_values NOTIFY valuesChanged)

public:
    explicit Debugger(QObject *parent = nullptr);
    ~Debugger();

    void connectToRemote(const int port);

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
    void selectFrame(const int frame);

    void getBacktrace();
    void clearBacktrace();
    void getFrameValues();
    void clearFrameValues();
    void getBacktraceAndFrameValues();

    void quitDebugger();
    void killDebugger();

private:
    void spawnDebugger();

    void readOutput();
    void readError();
    void read(FILE* io);
    void writeToStdIn(const QByteArray& input);

    QVariantMap filterStackFrame(const QString output);
    QVariantMap filterCallStack(const QString output);

    WasmRunner* runner();
    void setRunner(WasmRunner* runner);

    SystemGlue* system();
    void setSystem(SystemGlue* system);

    bool m_spawned;
    bool m_running;
    bool m_processPaused;
    WasmRunner* m_runner;
    SystemGlue* m_system;
    bool m_forceQuit;
    QString m_binary;
    QStringList m_args;
    std::pair<StdioSpec, StdioSpec> m_stdioPair;

    QThread m_debuggerThread;
    QThread m_readThreadOut;
    QThread m_readThreadErr;

    QStringList m_breakpoints;
    
    QMutex m_backtraceMutex;
    QVariantList m_backtrace;

    QMutex m_valuesMutex;
    QVariantList m_values;

signals:
    void runnerChanged();
    void systemChanged();
    void runningChanged();
    void processPaused();
    void processContinued();
    void processPausedChanged();
    void breakpointsChanged();
    void valuesChanged();
    void backtraceChanged();
    void attachedToProcess();
};

#endif // DEBUGGER_H
