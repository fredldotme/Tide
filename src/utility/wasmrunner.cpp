#include "wasmrunner.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

#include <cstring>
#include <iostream>
#include <fstream>
#include <cstdlib>

#include <unistd.h>
#include <stdio.h>
#include <signal.h>

#include "debugger.h"
#include "platform_internal.h"

//#include "api-bindings/opengles2.h"
//#include "api-bindings/qmlwindow.h"

constexpr uint32_t stack_size = 16777216;
constexpr uint32_t heap_size = 16777216;
constexpr uint32_t max_threads = 64;

#if USE_EMBEDDED_WAMR
void WasmRunner::init()
{
    RuntimeInitArgs init_args;
    memset(&init_args, 0, sizeof(RuntimeInitArgs));

    strcpy(init_args.ip_addr, "127.0.0.1");
    init_args.instance_port = 0;
    init_args.mem_alloc_type = Alloc_With_System_Allocator;
    init_args.max_thread_num = 64;

    wasm_runtime_full_init(&init_args);

    // Register native API bindings
    //register_wamr_opengles_bindings();
    //register_wamr_tideui_bindings();
    //register_wamr_sdl2_bindings();
}

void WasmRunner::deinit()
{
#ifdef TIDEUI_API_BINDING_H
    cleanup_wamr_tideui_memory();
#endif
    wasm_runtime_destroy();
}
#endif

WasmRunner::WasmRunner(QObject *parent)
    : QObject{parent}, m_running{false}, m_system{nullptr}, m_debugger{nullptr}
{
}

WasmRunner::~WasmRunner()
{
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

    m_running = false;
    emit runningChanged();
    emit runEnded(sharedData.main_result);
}

void* runInThread(void* userdata)
{
    WasmRunnerSharedData& shared = *static_cast<WasmRunnerSharedData*>(userdata);

#if USE_EMBEDDED_WAMR
    char error_buf[128];
    int main_result;
    const char *addr_pool[8] = { "0.0.0.0/0" };
    uint32_t addr_pool_size = 1;
    const char *ns_lookup_pool[8] = { "*" };
    uint32_t ns_lookup_pool_size = 1;
    std::vector<const char*> mappedDirs { "/" };

    std::vector<std::string> args;
    std::vector<const char*> cargs;
    std::vector<const char*> env;

    // Initialize WAMR environment
    WasmRunner::init();

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
                                  mappedDirs.data(), mappedDirs.size(),
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

    if (shared.debug) {
        wasm_exec_env_t debug_exec_env = wasm_runtime_get_exec_env_singleton(shared.module_inst);
        const auto debug_port = wasm_runtime_start_debug_instance(debug_exec_env);
        shared.debugger->connectToRemote(debug_port);

        wasm_runtime_wait_for_remote_start(debug_exec_env);
    }

    if (!wasm_application_execute_main(shared.module_inst, 0, NULL)) {
        if (!shared.killing) {
            const QString err = QStringLiteral("call wasm function main failed. error: %1\n").arg(wasm_runtime_get_exception(shared.module_inst));
            emit shared.runner->errorOccured(err);
        } else {
            emit shared.runner->runEnded(255);
        }
        goto fail;
    }

    shared.main_result = wasm_runtime_get_wasi_exit_code(shared.module_inst);
    shared.killed = false;
    if (shared.debug)
        shared.debugger->killDebugger();

    qDebug() << "Execution complete, exit code:" << shared.main_result;

fail:
    // Whether killed or not, we can reset state here
    shared.killing = false;
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

    WasmRunner::deinit();

    return nullptr;
#else
    shared.runner->signalStart();
    const auto command = QStringLiteral("iwasm --interp") +
                         QStringLiteral(" --stack-size=%1").arg(stack_size) +
                         QStringLiteral(" --heap-size=%1").arg(heap_size) +
                         QStringLiteral(" --max-threads=%1 ").arg(max_threads) +
                         (shared.debug ? QStringLiteral(" -g=127.0.0.1:1234") : QString()) +
                         shared.binary + QStringLiteral(" ") + shared.args.join(" ");
    if (shared.debug) {
        shared.runner->signalDebugSession(1234);
    }

    shared.main_result = shared.system->runCommand(command, shared.stdio);
    shared.runner->signalEnd();
    return nullptr;
#endif
}

void WasmRunner::run(const QString binary, const QStringList args)
{
    start(binary, args, false);
}

void WasmRunner::debug(const QString binary, const QStringList args)
{
    start(binary, args, true);
}

void WasmRunner::waitForFinished()
{
    pthread_join(m_runThread, nullptr);
}

int WasmRunner::exitCode()
{
    return this->sharedData.main_result;
}

void WasmRunner::start(const QString binary, const QStringList args, const bool debug)
{
    kill();

    QString applicationFile = binary;
    {
        const QString aotPath = binary + QStringLiteral(".aot");
        if (QFile::exists(aotPath)) {
            QFileInfo aot(aotPath);
            QFileInfo wasm(binary);

            if (aot.lastModified() > wasm.lastModified())
                applicationFile = aotPath;
        }
    }

    qDebug() << "Running" << applicationFile << args << debug;

    sharedData.binary = applicationFile;
    sharedData.args = args;
    sharedData.main_result = -1;

#if USE_EMBEDDED_WAMR
    sharedData.exec_env = nullptr;
    sharedData.module = nullptr;
    sharedData.module_inst = nullptr;

    sharedData.killing = false;

    // Set to true now so that we have to reset it after a successful run.
    sharedData.killed = true;
#else
    sharedData.system = m_system;
#endif

    sharedData.stdio = m_spec;
    sharedData.debug = debug;
    if (debug) {
        sharedData.debugger = m_debugger;
    }
    sharedData.runner = this;
    pthread_create(&m_runThread, nullptr, runInThread, &sharedData);
}

void WasmRunner::kill()
{
#if USE_EMBEDDED_WAMR
    sharedData.killing = true;
#endif

    if (sharedData.debug && m_debugger) {
        m_debugger->killDebugger();
        sharedData.debug = false;
    }

#if USE_EMBEDDED_WAMR
    if (sharedData.module_inst) {
        wasm_runtime_terminate(sharedData.module_inst);
    }
#endif

#if 0
#if USE_EMBEDDED_WAMR
    if (sharedData.exec_env) {
        wasm_runtime_destroy_exec_env(sharedData.exec_env);
        sharedData.exec_env = nullptr;
    }
    if (sharedData.module) {
        wasm_runtime_unload(sharedData.module);
        sharedData.module = nullptr;
    }
#endif
#endif

#ifdef TIDEUI_API_BINDING_H
    cleanup_wamr_tideui_memory();
#endif

    signalEnd();
}

void WasmRunner::prepareStdio(StdioSpec spec)
{
    m_spec = spec;
    qDebug() << "stdio prepared";
}

void WasmRunner::registerDebugger(Debugger* debugger)
{
    m_debugger = debugger;
}

bool WasmRunner::running()
{
    return m_running;
}
