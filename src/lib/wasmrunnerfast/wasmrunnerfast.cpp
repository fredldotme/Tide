#include "wasmrunnerfast.h"

#include <map>
#include <memory>

#include <cstring>
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <stdint.h>

#include <unistd.h>
#include <stdio.h>
#include <signal.h>

#include <pthread.h>
#include <stdint.h>
#include <memory>
#include <vector>
#include <string>

#include <wasm_c_api.h>
#include <wasm_export.h>

#include "common/wasmrunnerinterface.h"

#include "bh_read_file.h"

//#include "api-bindings/opengles2.h"
//#include "api-bindings/qmlwindow.h"

#if __APPLE__
#include <TargetConditionals.h>
extern "C" { extern int wamr_compiler_main(int argc, char* argv[]); }
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
#define SUPPORTS_AOT 0
#else
#define SUPPORTS_AOT 1
#endif
#else
#define SUPPORTS_AOT 0
#endif


struct WasmRunnerFastImplSharedData {
    WasmRunnerHost* host;
    std::string binary;
    int argc;
    char** argv;
    wasm_module_t module = nullptr;
    wasm_module_inst_t module_inst = nullptr;
    wasm_exec_env_t exec_env = nullptr;
    char* memoryPool = nullptr;
    bool killing;
    bool killed;
    WasmRunnerConfig configuration;
};

class WasmRunnerFastImpl : public WasmRunnerInterface
{
public:
    WasmRunnerFastImpl(WasmRuntimeHost host);
    virtual void init(const WasmRunnerConfig& config) override;
    virtual void destroy() override;
    virtual int exec(const std::string& path, int argc, char** argv, int infd, int outfd, int errfd, const bool debug, const std::string& readableDir) override;
    virtual void stop() override;

private:
    WasmRunnerFastImplSharedData shared;
};


WasmRunnerFastImpl::WasmRunnerFastImpl(WasmRuntimeHost host) :
    WasmRunnerInterface(host)
{
}

void WasmRunnerFastImpl::init(const WasmRunnerConfig& config)
{
    std::cout << "Configuring:" << std::endl;
    std::cout << "Stack size: " << config.stackSize << std::endl;
    std::cout << "Heap size:" << config.heapSize << std::endl;
    std::cout << "Thread count:" << config.threadCount << std::endl;

    shared.configuration = config;

    RuntimeInitArgs init_args;
    memset(&init_args, 0, sizeof(RuntimeInitArgs));

    init_args.running_mode = Mode_Interp;
    init_args.max_thread_num = config.threadCount;

    shared.memoryPool = new char[config.heapSize + config.stackSize];
    init_args.mem_alloc_type = Alloc_With_Pool;
    init_args.mem_alloc_option.pool.heap_buf = shared.memoryPool;
    init_args.mem_alloc_option.pool.heap_size = sizeof(shared.memoryPool);

    wasm_runtime_full_init(&init_args);

    // Register native API bindings
    //register_wamr_opengles_bindings();
    //register_wamr_tideui_bindings();
    //register_wamr_sdl2_bindings();

    shared.host = (WasmRunnerHost*)host;
}

void* mmap_wamr_file(const char* filename, unsigned int* size, int* fd)
{
    int file;
    uint32 file_size, buf_size, read_size;
    struct stat stat_buf;

    if (!filename || !size || !fd) {
        printf("Read file to buffer failed: invalid filename, ret size or fd.\n");
        return nullptr;
    }

    if ((file = open(filename, O_RDONLY, 0)) == -1) {
        printf("Read file to buffer failed: open file %s failed.\n", filename);
        return nullptr;
    }

    if (fstat(file, &stat_buf) != 0) {
        printf("Read file to buffer failed: fstat file %s failed.\n", filename);
        close(file);
        return nullptr;
    }

    file_size = (uint32)stat_buf.st_size;
    if (file_size == 0) {
        close(file);
        return nullptr;
    }

    void* ret = mmap(NULL, file_size, PROT_READ | PROT_EXEC, MAP_PRIVATE, file, 0);
    if (!ret) {
        close(file);
        return nullptr;
    }

    *size = file_size;
    *fd = file;
    return ret;
}

int WasmRunnerFastImpl::exec(const std::string& path, int argc, char** argv, int stdinfd, int stdoutfd, int stderrfd, const bool debug, const std::string& readableDir)
{
    char error_buf[128];
    int main_result;
    const char *addr_pool[8] = { "0.0.0.0/0" };
    uint32_t addr_pool_size = 1;
    const char *ns_lookup_pool[8] = { "*" };
    uint32_t ns_lookup_pool_size = 1;
    std::vector<const char*> mappedDirs { readableDir.c_str() };
    std::vector<const char*> env;
    std::string exepath = path;
    int exitCode = -1;
    bool useMmap = false;

    for (const auto& mappedDir : shared.configuration.mapDirs) {
        mappedDirs.push_back(mappedDir.c_str());
    }
    mappedDirs.push_back("/::/");

    WasmRunnerHost* hostInterface = static_cast<WasmRunnerHost*>(shared.host);
    if (!hostInterface) {
        std::cout << "Unable to access plugin host interface" << std::endl;
        goto fail;
    }

    std::cout << "Loading wasm: " << path << std::endl;
    for (int i = 0; i < argc; i++) {
        std::cout << "arg: " << argv[i] << std::endl;
    }

#if SUPPORTS_AOT
    if (shared.configuration.flags & WasmRunnerConfigFlags::AOT) {
        const auto aotpath = path + ".aot";
        std::vector<const char*> cmd;
        cmd.push_back("wamrc");
        cmd.push_back("--size-level=3");
        cmd.push_back("--opt-level=3");
        cmd.push_back("--format=aot");
        cmd.push_back("-o");
        cmd.push_back(aotpath.c_str());
        cmd.push_back(path.c_str());

        int cmdargc = cmd.size();
        char** cmdargv = (char**)cmd.data();
        hostInterface->report("Optimizing via AOT...");
        const auto compileRet = wamr_compiler_main(cmdargc, cmdargv);

        if (compileRet != 0) {
            std::string err; err = "AOT compilation failed with return code: " + std::to_string(compileRet);
            hostInterface->reportError(err);
            goto fail;
        } else {
            sync();
            std::cout << "AOT compilation successful" << std::endl;
            exepath = aotpath;
        }
    }
#endif
    unsigned int siz;
    uint8_t* buf;
    int fd;

    if (!useMmap) {
        siz = 0;
        buf = (uint8_t*)bh_read_file_to_buffer(path.c_str(), &siz);
    } else {
        fd = -1;
        siz = 0;
        buf = (uint8_t*)mmap_wamr_file(exepath.c_str(), &siz, &fd);
        if (!buf) {
            std::string reason; reason = std::string(error_buf);
            std::string err; err = "Failed to read file: " + exepath;
            hostInterface->reportError(err);
            goto fail;
        }
    }

    shared.module = wasm_runtime_load(buf, siz, error_buf, sizeof(error_buf));
    if (!shared.module) {
        std::string reason; reason = std::string(error_buf);
        std::string err; err = "Failed to load wasm module: " + reason;
        hostInterface->reportError(err);
        goto fail;
    }

    std::cout << "WasmRunnerFastImpl: host " << host << std::endl;

    wasm_runtime_set_wasi_args_ex(shared.module,
                                  nullptr, 0,
                                  mappedDirs.data(), mappedDirs.size(),
                                  env.data(), env.size(),
                                  argv, argc,
                                  stdinfd,
                                  stdoutfd,
                                  stderrfd);

    wasm_runtime_set_wasi_addr_pool(shared.module, addr_pool, addr_pool_size);
    wasm_runtime_set_wasi_ns_lookup_pool(shared.module, ns_lookup_pool, ns_lookup_pool_size);

    shared.module_inst = wasm_runtime_instantiate(shared.module,
                                                  shared.configuration.stackSize,
                                                  shared.configuration.heapSize,
                                                  error_buf, sizeof(error_buf));
    if (!shared.module_inst) {
        std::string reason; reason = std::string(error_buf);
        std::string err; err = "Failed to create module runtime: " + reason;
        hostInterface->reportError(err);
        goto fail;
    }

    shared.exec_env = wasm_runtime_create_exec_env(shared.module_inst, shared.configuration.stackSize);
    if (!shared.exec_env) {
        const auto reason = std::string(error_buf);
        const auto err = "Create wasm execution environment failed: " + reason;
        hostInterface->reportError(err);
        goto fail;
    }

    if (!wasm_application_execute_main(shared.module_inst, 0, NULL)) {
        if (!shared.killing) {
            const auto reason = std::string(wasm_runtime_get_exception(shared.module_inst));
            const auto err = "Uncaught exception: " + reason;
            hostInterface->reportError(err);
        } else {
            hostInterface->reportExit(255);
        }
        goto fail;
    }

    shared.killed = false;
    exitCode = wasm_runtime_get_wasi_exit_code(shared.module_inst);
    hostInterface->reportExit(exitCode);
    std::cout << "Execution complete, exit code:" << exitCode << std::endl;

fail:
    // Whether killed or not, we can reset state here
    shared.killing = false;

    if (!useMmap) {
        if (buf) {
            BH_FREE(buf);
            buf = nullptr;
        }
    } else {
        if (buf) {
            munmap(buf, siz);
            buf = nullptr;
        }
        if (fd >= 0) {
            close(fd);
            fd = -1;
        }
    }

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

    return exitCode;
}

void WasmRunnerFastImpl::destroy()
{
    wasm_runtime_destroy();
    if (shared.memoryPool) {
        delete[] shared.memoryPool;
        shared.memoryPool = nullptr;
    }
}

void WasmRunnerFastImpl::stop()
{
    shared.killing = true;
    if (shared.module_inst) {
        wasm_runtime_terminate(shared.module_inst);
    }

#ifdef TIDEUI_API_BINDING_H
    cleanup_wamr_tideui_memory();
#endif
}

extern "C" {
WasmRuntime init_wamr_runtime(WasmRuntimeHost host, const WasmRuntimeConfig config)
{
    auto runner = new WasmRuntimePrivate();
    if (!runner)
        return 0;

    runner->interface = new WasmRunnerFastImpl(host);
    runner->interface->init(*static_cast<WasmRunnerConfig*>(config));
    return (WasmRuntime)runner;
}

uint32_t start_wamr_runtime(WasmRuntime instance, const char* binary, int argc, char** argv, int infd, int outfd, int errfd, const bool debug, const char* readableDir)
{
    WasmRuntimePrivate* priv = (WasmRuntimePrivate*)(instance);

    if (!priv)
        return 0;

    const auto binpath = std::string(binary);
    const auto readablepath = std::string(readableDir);
    priv->interface->exec(binpath, argc, argv, infd, outfd, errfd, debug, readablepath);
    return 1;
}

uint32_t stop_wamr_runtime(WasmRuntime instance)
{
    WasmRuntimePrivate* priv = (WasmRuntimePrivate*)(instance);
    if (!priv)
        return 0;

    priv->interface->stop();
    return 1;
}

uint32_t destroy_wamr_runtime(WasmRuntime instance)
{
    WasmRuntimePrivate* priv = (WasmRuntimePrivate*)(instance);
    if (!priv)
        return 0;

    priv->interface->destroy();
    delete priv->interface;
    delete priv;
    return 1;
}

WasmRuntimeInterface interface_wamr_runtime(WasmRuntime instance)
{
    WasmRuntimePrivate* priv = (WasmRuntimePrivate*)(instance);
    if (!priv)
        return nullptr;

    return (WasmRuntimeInterface)priv->interface;
}
}
