#ifndef CLANGWRAPPER_H
#define CLANGWRAPPER_H

#include <QString>

#include <clang-c/Index.h>

class ClangWrapper
{
public:
    ClangWrapper();
    ~ClangWrapper();

    void* handle;
    CXIndex (*createIndex)(int, int);
    CXTranslationUnit (*createTranslationUnitFromSourceFile)(
        CXIndex, const char *, int,
        const char *const *, unsigned ,
        struct CXUnsavedFile *);
    CXCursor (*getTranslationUnitCursor)(CXTranslationUnit);
    unsigned (*visitChildren)(CXCursor,
                              CXCursorVisitor,
                              CXClientData);
    void (*disposeTranslationUnit)(CXTranslationUnit);
    void (*disposeIndex)(CXIndex);
    enum CXCursorKind (*getCursorKind)(CXCursor);
    CXString (*getCursorSpelling)(CXCursor);
    const char* (*getCString)(CXString);
    void (*disposeString)(CXString);
    void (*toggleCrashRecovery)(unsigned);
};

#endif // CLANGWRAPPER_H
