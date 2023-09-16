#ifndef TIDEUI_API_BINDING_H
#define TIDEUI_API_BINDING_H

#include <wasm_export.h>
#include <QObject>
#include <QDebug>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QThread>
#include <vector>

class WorkerThread : public QThread
{
    Q_OBJECT

public:
    explicit WorkerThread(QObject* parent = nullptr) : QThread(parent) {}
    
protected:
    void run() override {
        exit_code = exec();
    }

public:
    int exit_code;
};

class TideUIContext : public QObject {
    Q_OBJECT

public:
    explicit TideUIContext() : QObject(nullptr) {}

    WorkerThread* thrd = nullptr;
    QQmlEngine* engine = nullptr;
    QQmlComponent* rootComponent = nullptr;
};

__thread static TideUIContext* active_context = nullptr;

extern "C" {
static int wamr_binding_TideUI_RunMainLoop(wasm_exec_env_t exec_env, uint32_t context)
{
    auto module_inst = wasm_runtime_get_module_inst(exec_env);
    TideUIContext* context_ptr = (TideUIContext*)wasm_runtime_addr_app_to_native(module_inst, context);
    if (!context_ptr)
        return 1;

    context_ptr->thrd->start();
    context_ptr->thrd->wait();
    return context_ptr->thrd->exit_code;
}

static uint32_t wamr_binding_TideUI_CreateContext(wasm_exec_env_t exec_env, uint32_t qml_content)
{
    auto module_inst = wasm_runtime_get_module_inst(exec_env);
    char* content = (char*)wasm_runtime_addr_app_to_native(module_inst, qml_content);

    qDebug() << "Window content:" << content;

    TideUIContext* context = new TideUIContext;
    context->thrd = new WorkerThread(context);
    context->engine = new QQmlEngine(context);
    context->rootComponent = new QQmlComponent(context->engine);
    context->rootComponent->setData(QByteArray::fromRawData(content, qstrlen(content)), QUrl());

    qDebug() << context->rootComponent->errorString();

    active_context = context;
    context->thrd->start();
    context->thrd->wait();

    return wasm_runtime_addr_native_to_app(module_inst, (void*)context);
}

static void wamr_binding_TideUI_DeleteContext(wasm_exec_env_t exec_env, uint32_t context)
{
    auto module_inst = wasm_runtime_get_module_inst(exec_env);
    TideUIContext* context_ptr = (TideUIContext*)wasm_runtime_addr_app_to_native(module_inst, context);
    if (!context_ptr)
        return;

    if (active_context == context_ptr)
        active_context = nullptr;
    delete context_ptr;
}
}

#define ADD_SYMBOL(name, signature) \
    { #name, (void*) wamr_binding_##name, signature, nullptr }

static NativeSymbol tideui_native_symbols[] = {
    ADD_SYMBOL(TideUI_CreateContext, "(i)i"),
    ADD_SYMBOL(TideUI_RunMainLoop, "(i)i"),
    ADD_SYMBOL(TideUI_DeleteContext, "(i)")
};

void register_wamr_tideui_bindings() {
    const int n_native_symbols = sizeof(tideui_native_symbols) / sizeof(NativeSymbol);
    if (!wasm_runtime_register_natives("env", tideui_native_symbols, n_native_symbols)) {
        qWarning() << "Failed to register TideUI APIs";
    } else {
        qInfo() << "Successfully registered TideUI APIs";
    }
}

void cleanup_wamr_tideui_memory()
{
    if (active_context) {
        delete active_context;
        active_context = nullptr;
    }
}

#endif // TIDEUI_API_BINDING_H
