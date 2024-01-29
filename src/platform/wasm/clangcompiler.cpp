#include "clangcompiler.h"

#include <memory>
#include <set>
#include <system_error>

#include <QDebug>
#include <QStringList>

static bool initialized = false;

ClangCompiler::ClangCompiler()
{
    if (!initialized) {
        // TODO: Decide what could fit here
        initialized = true;
    }
}
