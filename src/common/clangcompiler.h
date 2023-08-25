#ifndef CLANGCOMPILER_H
#define CLANGCOMPILER_H

#include <QString>

class ClangCompiler
{
public:
    explicit ClangCompiler();

public:
    int invokeCompiler(QString cmd);
};

#endif // CLANGCOMPILER_H
