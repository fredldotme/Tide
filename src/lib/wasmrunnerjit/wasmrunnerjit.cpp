#include "wasmrunnerjit.h"

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
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
#define SUPPORTS_AOT 0
#else
#define SUPPORTS_AOT 0
#endif
#else
#define SUPPORTS_AOT 0
#endif

#if SUPPORTS_AOT
#include "aot_export.h"
#endif

struct WasmRunnerJITImplSharedData {
    WasmRunnerHost* host;
    std::string binary;
    int argc;
    char** argv;
    wasm_module_t module = nullptr;
    wasm_module_inst_t module_inst = nullptr;
    wasm_exec_env_t exec_env = nullptr;
    bool killing;
    bool killed;
    WasmRunnerConfig configuration;
};

class WasmRunnerJITImpl : public WasmRunnerInterface
{
public:
    WasmRunnerJITImpl(WasmRuntimeHost host);
    virtual void init(const WasmRunnerConfig& config) override;
    virtual void destroy() override;
    virtual int exec(const std::string& path, int argc, char** argv, int infd, int outfd, int errfd, const bool debug, const std::string& readableDir) override;
    virtual void stop() override;

private:
    WasmRunnerJITImplSharedData shared;
};


WasmRunnerJITImpl::WasmRunnerJITImpl(WasmRuntimeHost host) :
    WasmRunnerInterface(host)
{
}

void WasmRunnerJITImpl::init(const WasmRunnerConfig& config)
{
    std::cout << "Configuring:" << std::endl;
    std::cout << "Stack size: " << config.stackSize << std::endl;
    std::cout << "Heap size:" << config.heapSize << std::endl;
    std::cout << "Thread count:" << config.threadCount << std::endl;

    shared.configuration = config;

    RuntimeInitArgs init_args;
    memset(&init_args, 0, sizeof(RuntimeInitArgs));

    init_args.mem_alloc_type = Alloc_With_System_Allocator;
    init_args.max_thread_num = config.threadCount;
    init_args.llvm_jit_opt_level = 3;
    init_args.llvm_jit_size_level = 3;
    init_args.running_mode = Mode_LLVM_JIT;

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

int WasmRunnerJITImpl::exec(const std::string& path, int argc, char** argv, int stdinfd, int stdoutfd, int stderrfd, const bool debug, const std::string& readableDir)
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
    unsigned int siz = 0;
    uint8_t* buf = nullptr;
    int fd = -1;

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
        bool aotSuccess = false;
        const auto aotpath = path + ".aot";
        hostInterface->report("Optimizing via AOT...");

        AOTCompOption option = { 0 };
        option.opt_level = 3;
        option.size_level = 3;
        option.output_format = AOT_FORMAT_FILE;
        option.bounds_checks = 0;
        option.stack_bounds_checks = 0;
        option.enable_simd = true;
        option.enable_aux_stack_check = true;
        option.enable_bulk_memory = true;
        option.enable_thread_mgr = true;
        option.enable_ref_types = true;
        option.enable_tail_call = true;
        option.is_indirect_mode = true;
        option.disable_llvm_intrinsics = true;

        wasm_module_t wasm_module = NULL;
        aot_comp_data_t comp_data = NULL;
        aot_comp_context_t comp_ctx = NULL;
        uint8 *wasm_file = NULL;
        uint32 wasm_file_size;

        wasm_file = (uint8 *)bh_read_file_to_buffer(exepath.c_str(), &wasm_file_size);

        /* load WASM module */
        if (!(wasm_module = wasm_runtime_load(wasm_file, wasm_file_size, error_buf,
                                              sizeof(error_buf)))) {
            printf("%s\n", error_buf);
            goto aotFail;
        }

        if (!(comp_data = aot_create_comp_data(wasm_module))) {
            printf("%s\n", aot_get_last_error());
            goto aotFail;
        }

        if (!(comp_ctx = aot_create_comp_context(comp_data, &option))) {
            printf("%s\n", aot_get_last_error());
            goto aotFail;
        }

        if (aot_compile_wasm(comp_ctx)) {
            std::cout << "Compiled, saving " << aotpath << std::endl;
            aotSuccess = aot_emit_llvm_file(comp_ctx, aotpath.c_str());
        } else {
            std::cout << aot_get_last_error() << std::endl;
        }

aotFail:
        if (wasm_file)
            BH_FREE(wasm_file);
        if (comp_ctx)
            aot_destroy_comp_context(comp_ctx);
        if (comp_data)
            aot_destroy_comp_data(comp_data);
        if (wasm_module)
            wasm_runtime_unload(wasm_module);

        if (!aotSuccess) {
            std::string err; err = "AOT compilation failed";
            hostInterface->reportError(err);
            goto fail;
        } else {
            std::cout << "AOT compilation successful" << std::endl;
            exepath = aotpath;
            useMmap = true;
        }
    }
#endif

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

    std::cout << "WasmRunnerJITImpl: host " << host << std::endl;

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

void WasmRunnerJITImpl::destroy()
{
    wasm_runtime_destroy();
}

void WasmRunnerJITImpl::stop()
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

    runner->interface = new WasmRunnerJITImpl(host);
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
