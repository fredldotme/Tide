#ifndef WASMRUNNER_H
#define WASMRUNNER_H

#include <QObject>
#include <QThread>

#include <wasm3_cpp.h>

#include "programspec.h"

class WasmRunner : public QObject
{
    Q_OBJECT
public:
    explicit WasmRunner(QObject *parent = nullptr);
    void printStatement(QString content);

public slots:
    void run(const QString binary, const QStringList args);
    void kill();
    void prepareStdio(ProgramSpec spec);

private:
    void executeInThread();

    wasm3::environment m_env;
    wasm3::runtime m_runtime;
    QString m_binary;
    QStringList m_args;
    QThread m_runThread;

signals:
    void printfReceived(QString str);
    void errorOccured(QString str);
};

#endif // WASMRUNNER_H
