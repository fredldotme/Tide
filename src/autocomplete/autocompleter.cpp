#include "autocompleter.h"

#include <QDebug>

AutoCompleter::AutoCompleter(QObject *parent)
    : QObject{parent}, clang{nullptr}
{
    QObject::connect(&m_thread, &QThread::started, this, &AutoCompleter::run, Qt::DirectConnection);
}

QStringList& AutoCompleter::referenceHints()
{
    return this->m_referenceHints;
}

const QStringList AutoCompleter::referenceHintsConst()
{
    return this->m_referenceHints;
}

QList<AutoCompleter::CompletionHint>& AutoCompleter::currentAnchorDecls()
{
    return this->m_anchorDecls;
}

const QList<AutoCompleter::CompletionHint> AutoCompleter::currentAnchorDeclsConst()
{
    return this->m_anchorDecls;
}

QStringList AutoCompleter::createHints(const QString& hint)
{
    QStringList ret;
    QString subhint;

    qDebug() << "Creating hints based on" << hint;

    for(auto it = hint.constBegin(); it != hint.constEnd(); it++) {
        if (*it == QChar('-')) {
            if ((it+1) != hint.constEnd() && *(it+1) == QChar('>')) {
                ret << subhint;
                subhint.clear();
                ++it;
                continue;
            }
        } else if (*it == QChar(':')) {
            if ((it+1) != hint.constEnd() && *(it+1) == QChar(':')) {
                ret << subhint;
                subhint.clear();
                ++it;
                continue;
            }
        } else if (*it == QChar('.')) {
            ret << subhint;
            subhint.clear();
            continue;
        }

        if (it->isLetterOrNumber() || *it == QChar('_'))
            subhint += *it;
    }

    if (!subhint.isEmpty()) {
        ret << subhint;
    }

    qDebug() << "Hints:" << ret;
    return ret;
}

inline static AutoCompleter::CompletionKind getAutoCompleterKind(const CXCursorKind& kind)
{
    switch (kind) {
    case CXCursor_StructDecl:
        return AutoCompleter::CompletionKind::Struct;
    case CXCursor_UnionDecl:
        return AutoCompleter::CompletionKind::Union;
    case CXCursor_ClassDecl:
        return AutoCompleter::CompletionKind::Class;
    case CXCursor_EnumDecl:
        return AutoCompleter::CompletionKind::Enum;
    case CXCursor_FieldDecl:
        return AutoCompleter::CompletionKind::Field;
    case CXCursor_EnumConstantDecl:
        return AutoCompleter::CompletionKind::Enum;
    case CXCursor_FunctionDecl:
        return AutoCompleter::CompletionKind::Function;
    case CXCursor_VarDecl:
        return AutoCompleter::CompletionKind::Variable;
    default:
        return AutoCompleter::CompletionKind::Unspecified;
    }
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

    m_decls.clear();

    // This one prefers low memory usage over fast processing.
    if (unit) {
        CXCursor rootCursor = this->clang->getTranslationUnitCursor(unit);

        // Get all declarations
        if (this->referenceHints().length() > 0) {
            this->clang->visitChildren(rootCursor, [](CXCursor c, CXCursor, CXClientData client_data)
                {
                    AutoCompleter* thiz = reinterpret_cast<AutoCompleter*>(client_data);

                    if (thiz->clang->isCursorDefinition(c))
                        return CXChildVisit_Recurse;

                    CXCursorKind kind = thiz->clang->getCursorKind(c);
                    CompletionKind completionKind = getAutoCompleterKind(kind);

                    {
                        CXString spelling = thiz->clang->getCursorSpelling(c);
                        const QString name = QString::fromUtf8(thiz->clang->getCString(spelling));

                        // Add in case there's a match in the query
                        if (thiz->referenceHints().contains(name)) {
                            auto& anchors = thiz->currentAnchorDecls();
                            anchors.append({name, completionKind, c});
                        }

                        thiz->clang->disposeString(spelling);
                    }

                    return CXChildVisit_Recurse;
                }, this);
        }

        // Then resolve definitions
        this->clang->visitChildren(rootCursor, [](CXCursor c, CXCursor parent, CXClientData client_data)
            {
                AutoCompleter* thiz = reinterpret_cast<AutoCompleter*>(client_data);

                if (!thiz->clang->isCursorDefinition(c))
                    return CXChildVisit_Recurse;

                CXCursorKind parentKind = thiz->clang->getCursorKind(parent);
                CXCursor currentSemanticParent = thiz->clang->getCursorSemanticParent(c);
                CXCursorKind kind = thiz->clang->getCursorKind(c);
                CompletionKind parentCompletionKind = getAutoCompleterKind(parentKind);

                if (thiz->currentAnchorDecls().length() > 0) {
                    // Check whether we skimmed over its declaration
                    for (const auto& skimmedDecl : thiz->currentAnchorDecls()) {
                        if (!thiz->clang->equalCursors(currentSemanticParent, skimmedDecl.cursor)) {
                            continue;
                        }

                        CompletionKind completionKind = getAutoCompleterKind(kind);
                        CXString spelling = thiz->clang->getCursorSpelling(c);
                        const QString name = QString::fromUtf8(thiz->clang->getCString(spelling));
                        qDebug() << "Found skimmed kind:" << name;
                        thiz->foundKind(completionKind, name);
                        thiz->clang->disposeString(spelling);
                    }
                } else {
                    // Add any definition in case of an empty query
                    CompletionKind completionKind = getAutoCompleterKind(kind);
                    CXString spelling = thiz->clang->getCursorSpelling(c);
                    const QString name = QString::fromUtf8(thiz->clang->getCString(spelling));
                    qDebug() << "Found kind:" << name;
                    thiz->foundKind(completionKind, name);
                    thiz->clang->disposeString(spelling);
                }

                return CXChildVisit_Recurse;
            }, this);
    }

    currentAnchorDecls().clear();
    emit declsChanged();

    this->clang->disposeTranslationUnit(unit);
    this->clang->disposeIndex(index);
    this->clang = nullptr;
}

void AutoCompleter::reloadAst(const QString path, const QString hint)
{
    qDebug() << Q_FUNC_INFO << "with hint" << hint;

    this->m_path = path;
    this->m_referenceHints = createHints(hint);
    //this->m_thread.terminate();
    //this->m_thread.start();
    run();
}

void AutoCompleter::setIncludePaths(const QStringList paths)
{
    this->m_includePaths = paths;
}

QVariantList AutoCompleter::filteredDecls(const QString str)
{
    qDebug() << "Filter:" << str;
    QVariantList ret;
    for (const auto& decl : m_decls) {
        const auto declMap = decl.toMap();
        const auto declName = declMap.value("name").toString();
        if (declName.contains(str)) {
            ret << declMap;
        }
    }
    return ret;
}

void AutoCompleter::foundKind(CompletionKind kind, const QString name)
{
    QVariantMap decl;
    decl.insert("name", name);
    decl.insert("kind", kind);
    m_decls << decl;
}
