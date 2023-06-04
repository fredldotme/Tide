#include "autocompleter.h"

#include <QCoreApplication>
#include <QDebug>

#include <dlfcn.h>

AutoCompleter::AutoCompleter(QObject *parent)
    : QObject{parent}, handle{nullptr}
{
    QObject::connect(&m_thread, &QThread::started, this, &AutoCompleter::run, Qt::DirectConnection);

    const auto libPath = qApp->applicationDirPath() + "/Frameworks/libclang.framework/libclang";
    this->handle = dlopen(libPath.toUtf8().data(), RTLD_NOW);

    if (!this->handle) {
        qWarning() << "Failed to load libclang from" << libPath;
        return;
    }

    *(void**)(&clang_createIndex) = dlsym(this->handle, "clang_createIndex");
    *(void**)(&clang_createTranslationUnitFromSourceFile) = dlsym(this->handle, "clang_createTranslationUnitFromSourceFile");
    *(void**)(&clang_getTranslationUnitCursor) = dlsym(this->handle, "clang_getTranslationUnitCursor");
    *(void**)(&clang_visitChildren) = dlsym(this->handle, "clang_visitChildren");
    *(void**)(&clang_disposeTranslationUnit) = dlsym(this->handle, "clang_disposeTranslationUnit");
    *(void**)(&clang_disposeIndex) = dlsym(this->handle, "clang_disposeIndex");
    *(void**)(&clang_getCursorKind) = dlsym(this->handle, "clang_getCursorKind");
    *(void**)(&clang_getCursorSpelling) = dlsym(this->handle, "clang_getCursorSpelling");
    *(void**)(&clang_getCString) = dlsym(this->handle, "clang_getCString");
    *(void**)(&clang_disposeString) = dlsym(this->handle, "clang_disposeString");
}

AutoCompleter::~AutoCompleter()
{

}

void AutoCompleter::run()
{
    CXIndex index = clang_createIndex(0, 0);
    CXTranslationUnit unit = clang_createTranslationUnitFromSourceFile(index, m_path.toUtf8().data(), 0, nullptr, 0, nullptr);

    if (unit) {
        m_decls.clear();
        CXCursor rootCursor = clang_getTranslationUnitCursor(unit);
        clang_visitChildren(rootCursor, [](CXCursor c, CXCursor parent, CXClientData client_data)
            {
                AutoCompleter* thiz = reinterpret_cast<AutoCompleter*>(client_data);

                CXCursorKind kind = thiz->clang_getCursorKind(c);
                CXString spelling = thiz->clang_getCursorSpelling(c);

                CompletionKind completionKind = Unknown;

                switch(kind) {
                case CXCursor_VarDecl:
                    completionKind = Variable;
                    break;
                case CXCursor_FunctionDecl:
                    completionKind = Function;
                    break;
                default:
                    break;
                }

                if (completionKind != Unknown) {
                    const QString name = QString::fromUtf8(thiz->clang_getCString(spelling));
                    thiz->foundKind(completionKind, name);
                }

                thiz->clang_disposeString(spelling);

                return CXChildVisit_Recurse;
            }, this);

        emit declsChanged();
    }

    clang_disposeTranslationUnit(unit);
    clang_disposeIndex(index);
}

void AutoCompleter::reloadAst(const QString path)
{
    qDebug() << Q_FUNC_INFO;

    this->m_path = path;
    this->m_thread.terminate();
    this->m_thread.start();
}

void AutoCompleter::foundKind(CompletionKind kind, const QString name)
{
    QVariantMap decl;
    decl.insert("name", name);
    decl.insert("kind", kind);
    m_decls << decl;
}
