#include "clangcompiler.h"

#include <no_system/nosystem.h>

#include <memory>
#include <set>
#include <system_error>

#include <QDebug>
#include <QStringList>

#include <llvm/Support/LLVMDriver.h>

extern int clang_main(int argc, char **argv, const llvm::ToolContext &);
extern int lld_main(int argc, char **argv, const llvm::ToolContext &);
extern int lldb_main(int argc, char const **argv);

extern "C" {
extern int iwasm_main(int argc, char **argv);
extern int wamr_compiler_main(int argc, char **argv);
}

static int clang_hook(int argc, char **argv) {
    return clang_main(argc, (char**) argv, {argv[0], nullptr, false});
}

static int lld_hook(int argc, char **argv) {
    return lld_main(argc, (char**) argv, {argv[0], nullptr, false});
}

static int lldb_hook(int argc, char **argv) {
    return lldb_main(argc, (char const**) argv);
}

static bool initialized = false;

ClangCompiler::ClangCompiler()
{
    if (!initialized) {
        nosystem_addcommand("clang", &clang_hook);
        nosystem_addcommand("clang++", &clang_hook);
        nosystem_addcommand("lld", &lld_hook);
        nosystem_addcommand("ld", &lld_hook);
        nosystem_addcommand("wasm-ld", &lld_hook);
        nosystem_addcommand("lldb", &lldb_hook);
        nosystem_addcommand("iwasm", &iwasm_main);
        nosystem_addcommand("wamrc", &wamr_compiler_main);
        initialized = true;
    }
}
