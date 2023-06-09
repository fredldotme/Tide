#include "clangwrapper.h"

#include <QCoreApplication>

#include <dlfcn.h>

ClangWrapper::ClangWrapper()
{
    const auto libPath = qApp->applicationDirPath() + "/Frameworks/libclang.framework/libclang";
    this->handle = dlopen(libPath.toUtf8().data(), RTLD_NOW);

    if (!this->handle) {
        qWarning() << "Failed to load libclang from" << libPath;
        return;
    }

    *(void**)(&createIndex) = dlsym(this->handle, "clang_createIndex");
    *(void**)(&disposeIndex) = dlsym(this->handle, "clang_disposeIndex");
    *(void**)(&createTranslationUnitFromSourceFile) = dlsym(this->handle, "clang_createTranslationUnitFromSourceFile");
    *(void**)(&getTranslationUnitCursor) = dlsym(this->handle, "clang_getTranslationUnitCursor");
    *(void**)(&disposeTranslationUnit) = dlsym(this->handle, "clang_disposeTranslationUnit");
    *(void**)(&visitChildren) = dlsym(this->handle, "clang_visitChildren");
    *(void**)(&getCursorKind) = dlsym(this->handle, "clang_getCursorKind");
    *(void**)(&getCursorSpelling) = dlsym(this->handle, "clang_getCursorSpelling");
    *(void**)(&getCString) = dlsym(this->handle, "clang_getCString");
    *(void**)(&disposeString) = dlsym(this->handle, "clang_disposeString");
    *(void**)(&toggleCrashRecovery) = dlsym(this->handle, "clang_toggleCrashRecovery");
    *(void**)(&Cursor_isNull) = dlsym(this->handle, "clang_Cursor_isNull");
    *(void**)(&equalCursors) = dlsym(this->handle, "clang_equalCursors");
    *(void**)(&getCursorSemanticParent) = dlsym(this->handle, "clang_getCursorSemanticParent");
    *(void**)(&isCursorDefinition) = dlsym(this->handle, "clang_isCursorDefinition");
}

ClangWrapper::~ClangWrapper()
{
    if (this->handle) {
        dlclose(this->handle);
        this->handle = nullptr;
    }
}
