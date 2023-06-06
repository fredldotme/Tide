#ifndef WASMRUNNER_H
#define WASMRUNNER_H

#include <QObject>
#include <QThread>

#include <wasm_c_api.h>
#include <wasm_export.h>

#include "programspec.h"

class WasmRunner : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running MEMBER m_running NOTIFY runningChanged CONSTANT)

public:
    explicit WasmRunner(QObject *parent = nullptr);
    ~WasmRunner();

public slots:
    void run(const QString binary, const QStringList args);
    void kill();
    void prepareStdio(ProgramSpec spec);

private:
    void runInThread();

    wasm_module_t m_module;
    wasm_module_inst_t m_module_inst;
    wasm_exec_env_t m_exec_env;

    ProgramSpec m_spec;

    QString m_binary;
    QStringList m_args;
    QThread m_runThread;
    bool m_running;

signals:
    void printfReceived(QString str);
    void errorOccured(QString str);
    void runningChanged();
    void runEnded(int exitCode);
};

#endif // WASMRUNNER_H
