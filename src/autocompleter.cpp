#include "autocompleter.h"

#include <QDebug>

AutoCompleter::AutoCompleter(QObject *parent)
    : QObject{parent}
{
    QObject::connect(&m_thread, &QThread::started, this, &AutoCompleter::run, Qt::DirectConnection);
}

void AutoCompleter::run()
{
    CXIndex index = clang_createIndex(0, 0);
    CXTranslationUnit unit = clang_createTranslationUnitFromSourceFile(index, m_path.toUtf8().data(), 0, nullptr, 0, 0);
    if (unit == nullptr) {
        qDebug() << "No unit";
    }

    CXCursor rootCursor  = clang_getTranslationUnitCursor(unit);

    m_decls.clear();
    clang_visitChildren(rootCursor, [](CXCursor c, CXCursor parent, CXClientData client_data)
        {
            AutoCompleter* thiz = reinterpret_cast<AutoCompleter*>(client_data);

            CXCursorKind kind = clang_getCursorKind(c);
            CXString spelling = clang_getCursorSpelling(c);

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
                const QString name = QString::fromUtf8(clang_getCString(spelling));
                thiz->foundKind(completionKind, name);
            }

            clang_disposeString(spelling);

            return CXChildVisit_Recurse;
        }, this);

    clang_disposeTranslationUnit(unit);
    clang_disposeIndex(index);

    emit declsChanged();
}

void AutoCompleter::reloadAst(const QString path)
{
    qDebug() << Q_FUNC_INFO;
    m_path = path;

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
