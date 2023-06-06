#ifndef WASMRUNNER_H
#define WASMRUNNER_H

#include <QObject>
#include <QThread>

#include <wasm3_cpp.h>

#include "programspec.h"

class WasmRunner : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running MEMBER m_running NOTIFY runningChanged CONSTANT)

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
    bool m_running;

signals:
    void printfReceived(QString str);
    void errorOccured(QString str);
    void runningChanged();
};

#endif // WASMRUNNER_H
