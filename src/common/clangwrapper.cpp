#include "clangwrapper.h"

#include <QCoreApplication>

#include <dlfcn.h>

ClangWrapper::ClangWrapper()
{
#if defined(Q_OS_IOS)
    const auto libPath = qApp->applicationDirPath() + QStringLiteral("/Frameworks/libclang.framework/libclang");
#elif defined(Q_OS_MACOS)
    const auto libPath = qApp->applicationDirPath() + QStringLiteral("/../Frameworks/libclang.dylib");
#else
    const auto libPath = qApp->applicationDirPath() + QStringLiteral("/../lib/libclang.so");
#endif

    this->handle = dlopen(libPath.toStdString().c_str(), RTLD_NOW);

    if (!this->handle) {
        qWarning() << "Failed to load libclang functions";
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
    *(void**)(&getCursorLexicalParent) = dlsym(this->handle, "clang_getCursorLexicalParent");
    *(void**)(&isCursorDefinition) = dlsym(this->handle, "clang_isCursorDefinition");
    *(void**)(&getNullCursor) = dlsym(this->handle, "clang_getNullCursor");
    *(void**)(&getCursorType) = dlsym(this->handle, "clang_getCursorType");
    *(void**)(&getTypeSpelling) = dlsym(this->handle, "clang_getTypeSpelling");
    *(void**)(&getCursorExtent) = dlsym(this->handle, "clang_getCursorExtent");
    *(void**)(&getRangeStart) = dlsym(this->handle, "clang_getRangeStart");
    *(void**)(&getRangeEnd) = dlsym(this->handle, "clang_getRangeEnd");
    *(void**)(&getExpansionLocation) = dlsym(this->handle, "clang_getExpansionLocation");
    *(void**)(&getCursorReferenced) = dlsym(this->handle, "clang_getCursorReferenced");
    *(void**)(&parseTranslationUnit) = dlsym(this->handle, "clang_parseTranslationUnit");
}

ClangWrapper::~ClangWrapper()
{
    if (this->handle) {
        dlclose(this->handle);
        this->handle = nullptr;
    }
}
