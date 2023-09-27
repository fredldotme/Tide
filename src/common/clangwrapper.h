#ifndef CLANGWRAPPER_H
#define CLANGWRAPPER_H

#include <QString>

#include <clang-c/Index.h>
#include <clang-c/CXSourceLocation.h>

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
    CXTranslationUnit (*parseTranslationUnit)(
        CXIndex CIdx, const char *source_filename,
        const char *const *command_line_args, int num_command_line_args,
        struct CXUnsavedFile *unsaved_files, unsigned num_unsaved_files,
        unsigned options);
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
    int (*Cursor_isNull)(CXCursor);
    unsigned (*equalCursors)(CXCursor, CXCursor);
    CXCursor (*getCursorSemanticParent)(CXCursor);
    CXCursor (*getCursorLexicalParent)(CXCursor);
    unsigned (*isCursorDefinition)(CXCursor);
    CXCursor (*getNullCursor)(void);
    CXType (*getCursorType)(CXCursor);
    CXString (*getTypeSpelling)(CXType K);
    CXSourceRange (*getCursorExtent)(CXCursor);
    CXSourceLocation (*getRangeStart)(CXSourceRange);
    CXSourceLocation (*getRangeEnd)(CXSourceRange);
    void (*getExpansionLocation)(CXSourceLocation location,
                                 CXFile *file, unsigned *line,
                                 unsigned *column,
                                 unsigned *offset);
    CXCursor (*getCursorReferenced)(CXCursor);
};

#endif // CLANGWRAPPER_H
