#ifndef WASMRUNNER_H
#define WASMRUNNER_H

#include <QObject>
#include <QThread>

#include <wasm_c_api.h>
#include <wasm_export.h>

#include "stdiospec.h"

class WasmRunner;

struct WasmRunnerSharedData {
    QString binary;
    QStringList args;
    int main_result;
    StdioSpec stdio;
    wasm_module_t module;
    wasm_module_inst_t module_inst;
    wasm_exec_env_t exec_env;
    WasmRunner* runner;
};

class WasmRunner : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running MEMBER m_running NOTIFY runningChanged CONSTANT)

public:
    explicit WasmRunner(QObject *parent = nullptr);
    ~WasmRunner();

    void signalStart();
    void signalEnd();

public slots:
    void run(const QString binary, const QStringList args);
    void kill();
    void prepareStdio(StdioSpec spec);

private:
    StdioSpec m_spec;
    WasmRunnerSharedData sharedData;

    pthread_t m_runThread;
    bool m_running;

signals:
    void printfReceived(QString str);
    void errorOccured(QString str);
    void runningChanged();
    void runEnded(int exitCode);
};

#endif // WASMRUNNER_H
