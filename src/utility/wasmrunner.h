#ifndef WASMRUNNER_H
#define WASMRUNNER_H

#include <QObject>
#include <pthread.h>

#include <wasm_c_api.h>
#include <wasm_export.h>

#include "stdiospec.h"

class WasmRunner;

struct WasmRunnerSharedData {
    QString binary;
    QStringList args;
    int main_result;
    StdioSpec stdio;
    bool debug;
    wasm_module_t module = nullptr;
    wasm_module_inst_t module_inst = nullptr;
    wasm_exec_env_t exec_env = nullptr;
    WasmRunner* runner = nullptr;
};

class WasmRunner : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running MEMBER m_running NOTIFY runningChanged CONSTANT)

public:
    static void init();
    static void deinit();

    explicit WasmRunner(QObject *parent = nullptr);
    ~WasmRunner();

    void signalStart();
    void signalDebugSession(const int port);
    void signalEnd();

    bool running();

public slots:
    void run(const QString binary, const QStringList args);
    void debug(const QString binary, const QStringList args);
    void waitForFinished();
    int exitCode();
    void kill();
    void prepareStdio(StdioSpec spec);

private:
    void start(const QString binary, const QStringList args, const bool debug);

    StdioSpec m_spec;
    WasmRunnerSharedData sharedData;

    pthread_t m_runThread;
    bool m_running;

signals:
    void printfReceived(QString str);
    void errorOccured(QString str);
    void runningChanged();
    void runEnded(int exitCode);
    void debugSessionStarted(int port);
};

#endif // WASMRUNNER_H
