#ifndef WASMRUNNERINTERFACE_H
#define WASMRUNNERINTERFACE_H

#include <iostream>
#include <string>
#include <vector>
#include <memory>
#include <dlfcn.h>

typedef void* WasmRuntime;
typedef void* WasmRuntimeHost;
typedef void* WasmRuntimeConfig;

class WasmRunnerHost {
public:
    virtual void report(const std::string& msg) = 0;
    virtual void reportError(const std::string& err) = 0;
    virtual void reportExit(const int code) = 0;
    virtual void reportDebugPort(const uint32_t debugPort) = 0;
};

enum WasmRunnerConfigFlags {
    None = 0,
    JIT = (1 << 0),
    AOT = (1 << 1)
};

struct WasmRunnerConfig {
    unsigned int threadCount = 0;
    unsigned int stackSize = 0;
    unsigned int heapSize = 0;
    WasmRunnerConfigFlags flags;
    std::vector<std::string> mapDirs;
};

class WasmRunnerInterface {
public:
    WasmRunnerInterface(WasmRuntimeHost host) : host(host) {}
    virtual ~WasmRunnerInterface() {}

    virtual void init(const WasmRunnerConfig& config) = 0;
    virtual void destroy() = 0;
    virtual int exec(const std::string& path, int argc, char** argv, int infd, int outfd, int errfd, const bool debug, const std::string& readableDir) = 0;
    virtual void stop() = 0;
    WasmRuntimeHost host;
};

typedef WasmRunnerInterface* WasmRuntimeInterface;

// Public plugin-API
struct wamr_runtime {
    wamr_runtime() {
        handle = nullptr;
        init = nullptr;
        destroy = nullptr;
        start = nullptr;
        stop = nullptr;
        interface = nullptr;
    }
    wamr_runtime(const char* path) {
        handle = dlopen(path, RTLD_NOW);
        if (!handle) {
            std::cout << "Failed to load WasmRunner: " << dlerror() << std::endl;
            return;
        }

        *(void**)(&init) = dlsym(handle, "init_wamr_runtime");
        *(void**)(&destroy) = dlsym(handle, "destroy_wamr_runtime");
        *(void**)(&start) = dlsym(handle, "start_wamr_runtime");
        *(void**)(&stop) = dlsym(handle, "stop_wamr_runtime");
        *(void**)(&interface) = dlsym(handle, "interface_wamr_runtime");
    }

    ~wamr_runtime() {
        if (this->handle)
            dlclose(this->handle);
        this->handle = nullptr;
    }

    void* handle;
    WasmRuntime (*init)(WasmRuntimeHost, const WasmRuntimeConfig confg);
    uint32_t (*destroy)(WasmRuntime);
    uint32_t (*start)(WasmRuntime, const char*, int, char**, int, int, int, const bool, const char*);
    uint32_t (*stop)(WasmRuntime);
    WasmRuntimeInterface (*interface)(WasmRuntime);
};

static std::shared_ptr<wamr_runtime> wamr_runtime_load(const char* path)
{
    std::shared_ptr<wamr_runtime> plugin = std::make_shared<wamr_runtime>(path);
    return plugin;
}

// C-linkage to loadable plugins
extern "C" {
WasmRuntime init_wamr_runtime(WasmRuntimeHost host, const WasmRuntimeConfig confg);
uint32_t destroy_wamr_runtime(WasmRuntime instance);
uint32_t start_wamr_runtime(WasmRuntime instance, const char* binary, int argc, char** argv, int infd, int outfd, int errfd, const bool debug, const char* readableDir);
uint32_t stop_wamr_runtime(WasmRuntime instance);
WasmRuntimeInterface interface_wamr_runtime(WasmRuntime instance);
}

#endif
