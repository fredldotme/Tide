#include "clangcompiler.h"

#include <no_system/nosystem.h>

#include <memory>
#include <set>
#include <system_error>

#include <QDebug>
#include <QStringList>

#if 0
extern int cmake_main(int ac, char const* const* av);
extern int ninja_main(int argc, char** argv);

extern "C" {
extern int iwasm_main(int argc, char **argv);
extern int wamr_compiler_main(int argc, char **argv);
}

static int cmake_hook(int argc, char** argv) {
    return cmake_main(argc, (char const* const*) argv);
}
#endif

ClangCompiler::ClangCompiler()
{
    static bool initialized = false;
    if (!initialized) {
        nosystem_init();
#if 0
        nosystem_addcommand("iwasm", &iwasm_main);
        nosystem_addcommand("wamrc", &wamr_compiler_main);
        nosystem_addcommand("cmake", &cmake_hook);
        nosystem_addcommand("ninja", &ninja_main);
#endif
        initialized = true;
    }
}
