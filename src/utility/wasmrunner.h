#ifndef WASMRUNNER_H
#define WASMRUNNER_H

#include <QObject>
#include <pthread.h>
#include <string>

#include <wasm_c_api.h>
#include <wasm_export.h>

#include "common/wasmrunnerinterface.h"
#include "stdiospec.h"
#include "platform/systemglue.h"

class Debugger;
class WasmRunner;

struct WasmRunnerSharedData {
    QString binary;
    QStringList args;
    int main_result;
    StdioSpec stdio;
    bool debug;
    std::shared_ptr<wamr_runtime> lib;
    WasmRuntime runtime = nullptr;
    WasmRunner* runner = nullptr;
    SystemGlue* system = nullptr;
    Debugger* debugger = nullptr;
    bool killing = false;
};

class TideWasmRunnerHost : public WasmRunnerHost
{
public:
    TideWasmRunnerHost(WasmRunner* runner) : runner(runner) {}
    virtual void reportError(const std::string& err) override;
    virtual void reportExit(const int code) override;
    virtual void reportDebugPort(const uint32_t debugPort) override;
    WasmRunner* runner;
};

class WasmRunner : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running MEMBER m_running NOTIFY runningChanged CONSTANT)
    Q_PROPERTY(SystemGlue* system MEMBER m_system NOTIFY systemChanged)

public:
    explicit WasmRunner(QObject *parent = nullptr);
    ~WasmRunner();

    void signalStart();
    void signalEnd();
    bool running();

    WasmRunnerSharedData sharedData;

public slots:
    void run(const QString binary, const QStringList args);
    void debug(const QString binary, const QStringList args);
    void waitForFinished();
    int exitCode();
    void kill();
    void prepareStdio(StdioSpec spec);
    void registerDebugger(Debugger* debugger);

private:
    void start(const QString binary, const QStringList args, const bool debug);
    void stop(bool silent);

    StdioSpec m_spec;
    pthread_t m_runThread;
    SystemGlue* m_system;
    Debugger* m_debugger;
    bool m_running;
    TideWasmRunnerHost* m_runnerHost;

signals:
    void printfReceived(QString str);
    void errorOccured(QString str);
    void runningChanged();
    void runEnded(int exitCode);
    void debugSessionStarted(int port);
    void systemChanged();
};

#endif // WASMRUNNER_H
