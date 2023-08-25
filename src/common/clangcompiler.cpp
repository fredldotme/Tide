#include "clangcompiler.h"

#include <no_system/nosystem.h>

#include <memory>
#include <set>
#include <system_error>

#include <QDebug>
#include <QStringList>

extern int clang_main(int argc, char **argv);
extern int lld_main(int argc, char const **argv);

int lld_hook(int argc, char **argv) {
    return lld_main(argc, (char const**) argv);
}

static bool initialized = false;

ClangCompiler::ClangCompiler()
{
    if (!initialized) {
        // Initialize targets first, so that --version shows registered targets.
        nosystem_addcommand("clang", &clang_main);
        nosystem_addcommand("clang++", &clang_main);
        nosystem_addcommand("lld", &lld_hook);
        nosystem_addcommand("ld", &lld_hook);
        nosystem_addcommand("wasm-ld", &lld_hook);
        initialized = true;
    }
}

int ClangCompiler::invokeCompiler(QString cmd)
{
    return nosystem_system(cmd.toUtf8().data());
}
