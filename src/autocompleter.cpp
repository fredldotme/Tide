#include "autocompleter.h"

#include <QDebug>

AutoCompleter::AutoCompleter(QObject *parent)
    : QObject{parent}, clang{nullptr}
{
    QObject::connect(&m_thread, &QThread::started, this, &AutoCompleter::run, Qt::DirectConnection);
}

void AutoCompleter::run()
{
    ClangWrapper clang;
    this->clang = &clang;

    CXIndex index = this->clang->createIndex(0, 0);

    std::vector<const char*> args;
    for (const QString& path : this->m_includePaths) {
        args.push_back("-I");
        args.push_back(path.toUtf8().data());
    }

    CXTranslationUnit unit = this->clang->createTranslationUnitFromSourceFile(index, m_path.toUtf8().data(), args.size(), args.data(), 0, nullptr);

    if (unit) {
        m_decls.clear();
        CXCursor rootCursor = this->clang->getTranslationUnitCursor(unit);
        this->clang->visitChildren(rootCursor, [](CXCursor c, CXCursor parent, CXClientData client_data)
            {
                AutoCompleter* thiz = reinterpret_cast<AutoCompleter*>(client_data);

                CXCursorKind kind = thiz->clang->getCursorKind(c);
                CXString spelling = thiz->clang->getCursorSpelling(c);

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
                    const QString name = QString::fromUtf8(thiz->clang->getCString(spelling));
                    thiz->foundKind(completionKind, name);
                }

                thiz->clang->disposeString(spelling);

                return CXChildVisit_Recurse;
            }, this);

        emit declsChanged();
    }

    this->clang->disposeTranslationUnit(unit);
    this->clang->disposeIndex(index);
    this->clang = nullptr;
}

void AutoCompleter::reloadAst(const QString path)
{
    qDebug() << Q_FUNC_INFO;

    this->m_path = path;
    this->m_thread.terminate();
    this->m_thread.start();
}

void AutoCompleter::setIncludePaths(const QStringList paths)
{
    this->m_includePaths = paths;
}

void AutoCompleter::foundKind(CompletionKind kind, const QString name)
{
    QVariantMap decl;
    decl.insert("name", name);
    decl.insert("kind", kind);
    m_decls << decl;
}
