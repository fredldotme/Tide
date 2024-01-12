#include "clangcompiler.h"

#include <no_system/nosystem.h>

#include <QDebug>
#include <QStringList>

ClangCompiler::ClangCompiler()
{
    static bool initialized = false;
    if (!initialized) {
        nosystem_init();
        initialized = true;
    }
}
