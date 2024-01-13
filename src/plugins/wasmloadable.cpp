#include "wasmloadable.h"

#include <QDebug>
#include <QFile>

#include <iostream>

typedef uint8_t uint8;

WasmLoadable::WasmLoadable(const QString& path) :
    m_path(path),
    module{nullptr},
    module_inst{nullptr},
    exec_env{nullptr}
{
    char error_buf[128];
    uint32_t stack_size = 8092, heap_size = 8092;

    /* read WASM file into a memory buffer */
    QFile loadableFile(path);
    if (!loadableFile.exists())
        return;

    if (!loadableFile.open(QFile::ReadOnly))
        return;

    m_buffer = loadableFile.readAll();

    /* parse the WASM file from buffer and create a WASM module */
    module = wasm_runtime_load((uint8*)m_buffer.data(), m_buffer.size(), error_buf, sizeof(error_buf));

    /* create an instance of the WASM module (WASM linear memory is ready) */
    module_inst = wasm_runtime_instantiate(module, stack_size, heap_size,
                                           error_buf, sizeof(error_buf));

    /* creat an execution environment to execute the WASM functions */
    exec_env = wasm_runtime_create_exec_env(module_inst, stack_size);
    
    std::cout << "Exec env ready: " << exec_env << std::endl;
}

WasmLoadable::~WasmLoadable()
{
    if (exec_env) {
        wasm_runtime_destroy_exec_env(exec_env);
        exec_env = nullptr;
    }

    if (module_inst) {
        wasm_runtime_deinstantiate(module_inst);
        module_inst = nullptr;
    }

    if (module) {
        wasm_runtime_unload(module);
        module = nullptr;
    }
}

bool WasmLoadable::isValid()
{
    QFile wasmLoadable(m_path);
    if (!wasmLoadable.exists())
        return false;

    return module && module_inst && exec_env;
}

QString WasmLoadable::name()
{
    std::vector<wasm_val_t> args = {};
    const auto ret = call_wasm_function("tide_plugin_name", args);
    if (ret.of.i32 == 0)
        return QString();

    if (!wasm_runtime_validate_app_str_addr(module_inst, ret.of.i32)) {
        return QString();
    }

    return QString::fromUtf8(wasm_memory<char*>(ret.of.i32));
}

QString WasmLoadable::description()
{
    std::vector<wasm_val_t> args = {};
    const auto ret = call_wasm_function("tide_plugin_description", args);
    if (ret.of.i32 == 0)
        return QString();

    if (!wasm_runtime_validate_app_str_addr(module_inst, ret.of.i32)) {
        return QString();
    }

    return QString::fromUtf8(wasm_memory<char*>(ret.of.i32));
}

WasmLoadable::WasmLoaderFeature WasmLoadable::features()
{
    std::vector<wasm_val_t> args = {};
    const auto ret = call_wasm_function("tide_plugin_features", args);
    return static_cast<WasmLoadable::WasmLoaderFeature>(ret.of.i32);
}

WasmLoadableInterface WasmLoadable::interface(const WasmLoaderFeature feature)
{
    std::vector<wasm_val_t> args = {
        {
            .kind = WASM_I32,
            .of.i32 = feature
        }
    };
    const auto ret = call_wasm_function("tide_plugin_get_interface", args);
    return static_cast<WasmLoadableInterface>(ret.of.i32);
}
