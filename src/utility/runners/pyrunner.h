#ifndef PYRUNNER_H
#define PYRUNNER_H

#include <QObject>
#include <pthread.h>
#include <string>

#include <wasm_c_api.h>
#include <wasm_export.h>

#include "common/wasmrunnerinterface.h"
#include "stdiospec.h"
#include "platform/systemglue.h"

//class Debugger;
class PyRunner;

struct PyRunnerSharedData {
    QString binary;
    QStringList args;
    int main_result;
    StdioSpec stdio;
    bool debug;
    std::shared_ptr<wamr_runtime> lib;
    WasmRuntime runtime = nullptr;
    PyRunner* runner = nullptr;
    SystemGlue* system = nullptr;
    bool killing = false;
};

class TidePyRunnerHost : public WasmRunnerHost
{
public:
    TidePyRunnerHost(PyRunner* runner) : runner(runner) {}
    virtual void report(const std::string& msg) override;
    virtual void reportError(const std::string& err) override;
    virtual void reportExit(const int code) override;
    virtual void reportDebugPort(const uint32_t debugPort) override;
    PyRunner* runner;
};

class PyRunner : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running MEMBER m_running NOTIFY runningChanged CONSTANT)
    Q_PROPERTY(SystemGlue* system MEMBER m_system NOTIFY systemChanged)

public:
    explicit PyRunner(QObject *parent = nullptr);
    ~PyRunner();

    void signalStart();
    void signalEnd();
    bool running();

    PyRunnerSharedData sharedData;

public slots:
    void run(const QString binary, const QStringList args);
    void debug(const QString binary, const QStringList args);
    void waitForFinished();
    int exitCode();
    void kill();
    void prepareStdio(StdioSpec spec);
    void runRepl();

private:
    void start(const QString binary, const QStringList args, const bool debug);
    void stop(bool silent);

    StdioSpec m_spec;
    pthread_t m_runThread;
    SystemGlue* m_system;
    bool m_running;
    TidePyRunnerHost* m_runnerHost;

signals:
    void printfReceived(QString str);
    void message(QString str);
    void errorOccured(QString str);
    void runningChanged();
    void runEnded(int exitCode);
    void debugSessionStarted(int port);
    void systemChanged();
};

#endif // PYRUNNER_H
