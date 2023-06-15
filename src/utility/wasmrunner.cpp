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
    : QObject{parent}, m_module{nullptr}, m_module_inst{nullptr}, m_exec_env{nullptr}, m_running{false}
{
    QObject::connect(&m_runThread, &QThread::started, this, &WasmRunner::runInThread, Qt::DirectConnection);
    wasm_runtime_init();
}

WasmRunner::~WasmRunner()
{
    wasm_runtime_destroy();
}

void WasmRunner::run(const QString binary, const QStringList args)
{
    qDebug() << "Running" << binary << args;

    m_binary = binary;
    m_args = args;

    kill();

    m_runThread.terminate();
    m_runThread.wait(1000);
    m_runThread.start();
}

void WasmRunner::runInThread()
{
    char error_buf[128];
    int main_result;
    const char *addr_pool[8] = { "0.0.0.0/0" };
    uint32_t addr_pool_size = 1;
    const char *ns_lookup_pool[8] = { "*" };
    uint32_t ns_lookup_pool_size = 1;

    std::vector<std::string> args;
    std::vector<const char*> cargs;
    std::vector<const char*> env;

    QFile m_binaryFile(m_binary);
    if (!m_binaryFile.open(QFile::ReadOnly)) {
        emit errorOccured("Failed to read binary");
        return;
    }

    const QByteArray binaryContents = m_binaryFile.readAll();

    m_module = wasm_runtime_load((uint8_t*)binaryContents.data(), binaryContents.size(), error_buf, sizeof(error_buf));
    if (!m_module) {
        const auto err = QString::fromUtf8(error_buf, strlen(error_buf));
        emit errorOccured(QStringLiteral("Failed to load wasm module: %1").arg(err));
        goto fail;
    }

    args.push_back(m_binary.toStdString());
    for (const auto& arg : m_args) {
        args.push_back(arg.toStdString());
    }
    for (const auto& arg : args) {
        cargs.push_back(arg.c_str());
    }

    wasm_runtime_set_wasi_args_ex(m_module,
                                  nullptr, 0,
                                  nullptr, 0,
                                  env.data(), env.size(),
                                  (char**)cargs.data(), cargs.size(),
                                  dup(fileno(m_spec.stdin)),
                                  dup(fileno(m_spec.stdout)),
                                  dup(fileno(m_spec.stderr)));

    wasm_runtime_set_wasi_addr_pool(m_module, addr_pool, addr_pool_size);
    wasm_runtime_set_wasi_ns_lookup_pool(m_module, ns_lookup_pool, ns_lookup_pool_size);

    m_module_inst = wasm_runtime_instantiate(m_module, stack_size, heap_size, error_buf, sizeof(error_buf));
    if (!m_module_inst) {
        const auto error = QString::fromUtf8(error_buf);
        emit errorOccured("Failed to create module runtime: " + error);
        goto fail;
    }

    m_exec_env = wasm_runtime_create_exec_env(m_module_inst, stack_size);
    if (!m_exec_env) {
        emit errorOccured("Create wasm execution environment failed.");
        goto fail;
    }

    m_running = true;
    emit runningChanged();

    if (!wasm_application_execute_main(m_module_inst, 0, NULL)) {
        const QString err = QStringLiteral("call wasm function main failed. error: %1\n").arg(wasm_runtime_get_exception(m_module_inst));
        emit errorOccured(err);
        goto fail;
    }

    main_result = wasm_runtime_get_wasi_exit_code(m_module_inst);
    emit runEnded(main_result);

fail:
    kill();
}

void WasmRunner::kill()
{
    if (m_running) {
        m_running = false;
        emit runningChanged();
    }
    if (m_exec_env) {
        wasm_runtime_destroy_exec_env(m_exec_env);
        m_exec_env = nullptr;
    }
    if (m_module_inst) {
        wasm_runtime_deinstantiate(m_module_inst);
        m_module_inst = nullptr;
    }
    if (m_module) {
        wasm_runtime_unload(m_module);
        m_module = nullptr;
    }
}

void WasmRunner::prepareStdio(StdioSpec spec)
{
    m_spec = spec;
    qDebug() << "stdio prepared";
}
