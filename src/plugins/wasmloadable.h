#ifndef WASMLOADABLE_H
#define WASMLOADABLE_H

#include <QObject>

#include <wasm_c_api.h>
#include <wasm_export.h>

#include <vector>

typedef int32_t WasmLoadableInterface;

class WasmLoadable
{
public:
    enum WasmLoaderFeature {
        NoneFeature = 0, // No-op feature that unit testing might need
        IDEProject = (1 << 1),
        IDEConsole = (1 << 2),
        IDEContextMenu = (1 << 3),
        IDEDebugger = (1 << 4),
        IDEAutoComplete = (1 << 5),
    };

    WasmLoadable(const QString& path = QString());
    ~WasmLoadable();
    Q_DISABLE_COPY(WasmLoadable)

public:
    bool isValid();
    WasmLoaderFeature features();

    QString name();
    QString description();
    WasmLoadableInterface interface(const WasmLoaderFeature feature);

    template<typename T>
    T wasm_memory(uint32_t addr) {
        return static_cast<T>(wasm_runtime_addr_app_to_native(module_inst, addr));
    }

    wasm_val_t call_wasm_function(const QString& funcName, std::vector<wasm_val_t> &args) {
        if (funcName.isEmpty()) {
            wasm_val_t ret;
            memset(&ret, 0, sizeof(ret));
            return ret;
        }

        wasm_val_t results[1];
        std::vector<wasm_val_t> argv;
        argv.resize(args.size());

        {
            int i = 0;
            for (const auto arg : args) {
                memcpy(&argv[i++], &arg, sizeof(arg));
            }
        }

        wasm_function_inst_t func = wasm_runtime_lookup_function(module_inst, funcName.toLocal8Bit().data());
        if (!func) {
            wasm_val_t ret;
            memset(&ret, 0, sizeof(ret));
            return ret;
        }

        if (!wasm_runtime_call_wasm_a(exec_env, func, 1, results, argv.size(), argv.data())) {
            printf("Exception: %s\n", wasm_runtime_get_exception(module_inst));
            wasm_val_t ret;
            memset(&ret, 0, sizeof(ret));
            return ret;
        }

        return results[0];
    }

    uint32_t make_buffer(size_t size, void** buf) {
        return wasm_runtime_module_malloc(module_inst, size, buf);
    }

    void free_buffer(uint32_t ptr) {
        wasm_runtime_module_free(module_inst, ptr);
    }

private:
    QString m_path;
    QByteArray m_buffer;

    wasm_module_t module;
    wasm_module_inst_t module_inst;
    wasm_exec_env_t exec_env;
};

#endif // WASMLOADABLE_H
