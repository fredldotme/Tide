#ifndef DEBUGGER_H
#define DEBUGGER_H

#include <QObject>
#include <QMutex>
#include <QString>
#include <QStringList>
#include <QThread>
#include <QTimer>
#include <QVariantMap>

#include "utility/runners/wasmrunner.h"
#include "platform/systemglue.h"
#include "common/directorylisting.h"

class Debugger : public QObject
{
    Q_OBJECT

    Q_PROPERTY(WasmRunner* runner READ runner WRITE setRunner NOTIFY runnerChanged)
    Q_PROPERTY(SystemGlue* system READ system WRITE setSystem NOTIFY systemChanged)
    Q_PROPERTY(bool running MEMBER m_running NOTIFY runningChanged);
    Q_PROPERTY(bool paused MEMBER m_processPaused NOTIFY processPausedChanged);
    Q_PROPERTY(QStringList breakpoints MEMBER m_breakpoints NOTIFY breakpointsChanged)
    Q_PROPERTY(QStringList watchpoints MEMBER m_watchpoints NOTIFY watchpointsChanged)
    Q_PROPERTY(QVariantList waitingpoints READ waitingpoints NOTIFY waitingpointsChanged)
    Q_PROPERTY(QVariantList backtrace MEMBER m_backtrace NOTIFY backtraceChanged)
    Q_PROPERTY(QVariantList values MEMBER m_values NOTIFY valuesChanged)
    Q_PROPERTY(QString currentLineOfExecution MEMBER m_currentLineOfExecution NOTIFY currentLineOfExecutionChanged)

public:
    explicit Debugger(QObject *parent = nullptr);
    ~Debugger();

    void connectToRemote(const int port);

public slots:
    void debug(const QString binary, const QStringList args);
    void runDebugSession();
    void addBreakpoint(const QString& breakpoint);
    void addWatchpoint(const QString& watchpoint);
    void removeBreakpoint(const QString& breakpoint);
    void removeWatchpoint(const QString& breakpoint);
    bool hasBreakpoint(const QString& breakpoint);
    bool hasWatchpoint(const QString& watchpoint);
    QVariantList waitingpoints();

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

    DirectoryListing getFileForActiveLine();

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
    QStringList m_watchpoints;
    
    QMutex m_backtraceMutex;
    QVariantList m_backtrace;

    QMutex m_valuesMutex;
    QVariantList m_values;
    QString m_currentFile;
    QString m_currentLineOfExecution;

signals:
    void runnerChanged();
    void systemChanged();
    void runningChanged();
    void processPaused();
    void hintPauseMessage();
    void processContinued();
    void processPausedChanged();
    void breakpointsChanged();
    void watchpointsChanged();
    void waitingpointsChanged();
    void valuesChanged();
    void backtraceChanged();
    void attachedToProcess();
    void currentLineOfExecutionChanged();
};

#endif // DEBUGGER_H
