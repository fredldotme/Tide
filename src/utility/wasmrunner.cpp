#include "wasmrunner.h"

#include <QDebug>
#include <QFile>
#include <QStandardPaths>

#include <iostream>
#include <fstream>

#include <unistd.h>

constexpr uint32_t stack_size = 1048576;
constexpr uint32_t heap_size = 1048576;

WasmRunner::WasmRunner(QObject *parent)
    : QObject{parent}, m_running{false}
{
    wasm_runtime_init();
}

WasmRunner::~WasmRunner()
{
    wasm_runtime_destroy();
}


void WasmRunner::signalStart()
{
    m_running = true;
    emit runningChanged();
}

void WasmRunner::signalEnd()
{
    if (!m_running)
        return;

    if (sharedData.main_result >= 0) {
        emit runEnded(sharedData.main_result);
    }

    m_running = false;
    emit runningChanged();
}

void* runInThread(void* userdata)
{
    char error_buf[128];
    int main_result;
    const char *addr_pool[8] = { "0.0.0.0/0" };
    uint32_t addr_pool_size = 1;
    const char *ns_lookup_pool[8] = { "*" };
    uint32_t ns_lookup_pool_size = 1;

    WasmRunnerSharedData& shared = *static_cast<WasmRunnerSharedData*>(userdata);

    std::vector<std::string> args;
    std::vector<const char*> cargs;
    std::vector<const char*> env;

    // Make this thread killable the dirty way
    pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, nullptr);

    QFile m_binaryFile(shared.binary);
    if (!m_binaryFile.open(QFile::ReadOnly)) {
        emit shared.runner->errorOccured("Failed to read binary");
        return nullptr;
    }

    const QByteArray binaryContents = m_binaryFile.readAll();

    shared.module = wasm_runtime_load((uint8_t*)binaryContents.data(), binaryContents.size(), error_buf, sizeof(error_buf));
    if (!shared.module) {
        const auto err = QString::fromUtf8(error_buf, strlen(error_buf));
        emit shared.runner->errorOccured(QStringLiteral("Failed to load wasm module: %1").arg(err));
        goto fail;
    }

    args.push_back(shared.binary.toStdString());
    for (const auto& arg : shared.args) {
        args.push_back(arg.toStdString());
    }
    for (const auto& arg : args) {
        cargs.push_back(arg.c_str());
    }

    wasm_runtime_set_wasi_args_ex(shared.module,
                                  nullptr, 0,
                                  nullptr, 0,
                                  env.data(), env.size(),
                                  (char**)cargs.data(), cargs.size(),
                                  dup(fileno(shared.stdio.stdin)),
                                  dup(fileno(shared.stdio.stdout)),
                                  dup(fileno(shared.stdio.stderr)));

    wasm_runtime_set_wasi_addr_pool(shared.module, addr_pool, addr_pool_size);
    wasm_runtime_set_wasi_ns_lookup_pool(shared.module, ns_lookup_pool, ns_lookup_pool_size);

    shared.module_inst = wasm_runtime_instantiate(shared.module, stack_size, heap_size, error_buf, sizeof(error_buf));
    if (!shared.module_inst) {
        const auto error = QString::fromUtf8(error_buf);
        emit shared.runner->errorOccured("Failed to create module runtime: " + error);
        goto fail;
    }

    shared.exec_env = wasm_runtime_create_exec_env(shared.module_inst, stack_size);
    if (!shared.exec_env) {
        emit shared.runner->errorOccured("Create wasm execution environment failed.");
        goto fail;
    }

    shared.runner->signalStart();

    if (!wasm_application_execute_main(shared.module_inst, 0, NULL)) {
        const QString err = QStringLiteral("call wasm function main failed. error: %1\n").arg(wasm_runtime_get_exception(shared.module_inst));
        emit shared.runner->errorOccured(err);
        goto fail;
    }

    shared.main_result = wasm_runtime_get_wasi_exit_code(shared.module_inst);

fail:
    shared.runner->signalEnd();

    if (shared.exec_env) {
        wasm_runtime_destroy_exec_env(shared.exec_env);
        shared.exec_env = nullptr;
    }
    if (shared.module_inst) {
        wasm_runtime_deinstantiate(shared.module_inst);
        shared.module_inst = nullptr;
    }
    if (shared.module) {
        wasm_runtime_unload(shared.module);
        shared.module = nullptr;
    }

    return nullptr;
}

void WasmRunner::run(const QString binary, const QStringList args)
{
    qDebug() << "Running" << binary << args;

    kill();

    sharedData.binary = binary;
    sharedData.args = args;
    sharedData.main_result = -1;
    sharedData.exec_env = nullptr;
    sharedData.module = nullptr;
    sharedData.module_inst = nullptr;
    sharedData.stdio = m_spec;
    sharedData.runner = this;

    pthread_create(&m_runThread, nullptr, runInThread, &sharedData);
}

void WasmRunner::kill()
{
    if (m_runThread) {
        pthread_cancel(m_runThread);
        pthread_join(m_runThread, nullptr);
    }
    if (sharedData.exec_env) {
        wasm_runtime_destroy_exec_env(sharedData.exec_env);
        sharedData.exec_env = nullptr;
    }
    if (sharedData.module_inst) {
        wasm_runtime_deinstantiate(sharedData.module_inst);
        sharedData.module_inst = nullptr;
    }
    if (sharedData.module) {
        wasm_runtime_unload(sharedData.module);
        sharedData.module = nullptr;
    }
    signalEnd();
}

void WasmRunner::prepareStdio(StdioSpec spec)
{
    m_spec = spec;
    qDebug() << "stdio prepared";
}
