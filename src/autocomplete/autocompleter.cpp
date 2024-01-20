#include "autocompleter.h"

#include <QDebug>
#include <QDir>
#include <QStandardPaths>
#include <QTimer>
#include <QMutexLocker>

AutoCompleter::AutoCompleter(QObject *parent)
    : QObject{parent}, clang{nullptr}, m_pluginManager{nullptr}
{
    QObject::connect(&m_thread, &QThread::started, this, &AutoCompleter::run, Qt::DirectConnection);
}

QStringList AutoCompleter::createHints(const QString& hint)
{
    QStringList ret;
    QString subhint;

    qDebug() << "Creating hints based on" << hint;

    for(auto it = hint.constBegin(); it != hint.constEnd(); it++) {
        if (*it == QChar('-')) {
            if ((it+1) != hint.constEnd() && *(it+1) == QChar('>')) {
                ret << subhint.toLower();
                subhint.clear();
                ++it;
                continue;
            }
        } else if (*it == QChar(':')) {
            if ((it+1) != hint.constEnd() && *(it+1) == QChar(':')) {
                ret << subhint.toLower();
                subhint.clear();
                ++it;
                continue;
            }
        } else if (*it == QChar('.')) {
            ret << subhint.toLower();
            subhint.clear();
            continue;
        }

        if (it->isLetterOrNumber() || *it == QChar('_'))
            subhint += *it;
    }

    if (!subhint.isEmpty()) {
        ret << subhint.toLower();
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
    case CXCursor_ParmDecl:
        return AutoCompleter::CompletionKind::Parameter;
    default:
        return AutoCompleter::CompletionKind::Unspecified;
    }
}

void AutoCompleter::run()
{
    // Preparations
    ClangWrapper clang;
    {
        QMutexLocker<QMutex> locker(&clangMutex);
        this->clang = &clang;
    }

    m_declsInProgress.clear();

    // First from the associated plugins
    if (m_pluginManager) {
        auto plugins = m_pluginManager->pluginRefs();
        for (auto& plugin : plugins) {
            if (!plugin->isValid()) {
                qDebug() << "Plugin is invalid";
                continue;
            }

            if (!(plugin->features() & WasmLoadable::IDEAutoComplete)) {
                qDebug() << "Not a AutoComplete plugin";
                continue;
            }

            const auto interface = plugin->interface(WasmLoadable::IDEAutoComplete);
            if (interface == 0) {
                qDebug() << "No interface returned";
                continue;
            }

            for (const auto& sourceFile : this->sourceFiles) {
                char * buffer = NULL;

                QFile source(sourceFile);
                if (!source.open(QFile::ReadOnly)) {
                    continue;
                }

                QByteArray contents = source.readAll();

                {
                    uint32_t buffer_for_wasm = plugin->loadable()->make_buffer(contents.length() + 1, (void**)&buffer);
                    if (buffer_for_wasm == 0)
                        continue;

                    strncpy(buffer, contents.toStdString().c_str(), hint.length());
                    buffer[hint.length()] = '\0';

                    std::vector<wasm_val_t> setupArgs = {
                        {
                            .kind = WASM_I32,
                            .of {
                                .i32 = interface
                            }
                        },{
                            .kind = WASM_I32,
                            .of {
                                .i32 = (int32_t)buffer_for_wasm
                            }
                        }
                    };
                    const auto setup = plugin->loadable()->call_wasm_function("tide_plugin_autocompletor_setup", setupArgs);
                    plugin->loadable()->free_buffer(buffer_for_wasm);
                }

                {
                    uint32_t buffer_for_wasm = plugin->loadable()->make_buffer(hint.length() + 1, (void**)&buffer);
                    if (buffer_for_wasm == 0)
                        continue;

                    strncpy(buffer, hint.toStdString().c_str(), hint.length());
                    buffer[hint.length()] = '\0';

                    std::vector<wasm_val_t> args = {
                        {
                            .kind = WASM_I32,
                            .of {
                                .i32 = interface
                            }
                        },
                        {
                            .kind = WASM_I32,
                            .of {
                                .i32 = (int32_t)buffer_for_wasm
                            }
                        }
                    };
                    auto finder = plugin->loadable()->call_wasm_function("tide_plugin_autocompletor_find", args);
                    plugin->loadable()->free_buffer(buffer_for_wasm);

                    if (!finder.of.i32)
                        continue;

                    do {
                        std::vector<wasm_val_t> typeArgs = {
                            {
                                .kind = WASM_I32,
                                .of {
                                    .i32 = finder.of.i32
                                }
                            }
                        };
                        const auto typeRet = plugin->loadable()->call_wasm_function("tide_plugin_autocompletorresult_type", typeArgs);
                        const auto prefix = QString::fromUtf8(plugin->loadable()->wasm_memory<char*>(typeRet.of.i32));

                        std::vector<wasm_val_t> idArgs = {
                            {
                                .kind = WASM_I32,
                                .of {
                                    .i32 = finder.of.i32
                                }
                            }
                        };
                        const auto idRet = plugin->loadable()->call_wasm_function("tide_plugin_autocompletorresult_identifier", idArgs);
                        const auto id = QString::fromUtf8(plugin->loadable()->wasm_memory<char*>(idRet.of.i32));

                        std::vector<wasm_val_t> detailArgs = {
                            {
                                .kind = WASM_I32,
                                .of {
                                    .i32 = finder.of.i32
                                }
                            }
                        };
                        const auto detailRet = plugin->loadable()->call_wasm_function("tide_plugin_autocompletorresult_detail", detailArgs);
                        const auto detail = QString::fromUtf8(plugin->loadable()->wasm_memory<char*>(detailRet.of.i32));

                        std::vector<wasm_val_t> kindArgs = {
                            {
                                .kind = WASM_I32,
                                .of {
                                    .i32 = finder.of.i32
                                }
                            }
                        };
                        const auto kindRet = plugin->loadable()->call_wasm_function("tide_plugin_autocompletorresult_kind", kindArgs);
                        const auto kind = static_cast<CompletionKind>(kindRet.of.i32);

                        foundKind(kind, prefix, id, detail);

                        std::vector<wasm_val_t> nextArgs = {
                            {
                                .kind = WASM_I32,
                                .of {
                                    .i32 = interface
                                }
                            }
                        };
                        const auto next = plugin->loadable()->call_wasm_function("tide_plugin_autocompletor_next", nextArgs);
                        if (next.of.i32 == finder.of.i32) {
                            qWarning() << "No new autocompletion result fetched, breaking loop";
                            break;
                        } else {
                            finder = next;
                        }
                    } while (finder.of.i32 != 0);
                }
            }
        }
    }

    // Then using Clang
    for (const auto& sourceFile : this->sourceFiles) {
        CXIndex index = this->clang->createIndex(0, 0);

        QByteArrayList tmpArgs = {
            QStringLiteral("--sysroot=%1").arg(this->m_sysroot).toUtf8()
        };

        tmpArgs << QStringLiteral("-I%1/include").arg(this->m_sysroot).toUtf8();
        for (const auto& tmpArg : m_includePaths) {
            tmpArgs << QStringLiteral("-I%1").arg(tmpArg).toUtf8();
        }

        std::vector<const char*> args = { "-x", "c++", "-I." };
        for (const auto& path : tmpArgs) {
            args.push_back(path.data());
        }

        CXTranslationUnit unit = this->clang->createTranslationUnitFromSourceFile(index, sourceFile.toUtf8().data(), args.size(), args.data(), 0, nullptr);

        if (unit) {
            this->rootCursor = this->clang->getTranslationUnitCursor(unit);
            this->deepestParent = this->clang->getNullCursor();

            this->clang->visitChildren(rootCursor, [](CXCursor c, CXCursor parent, CXClientData client_data)
                {
                    AutoCompleter* thiz = reinterpret_cast<AutoCompleter*>(client_data);
                    CXSourceRange cursorRange = thiz->clang->getCursorExtent(c);
                    auto ret = CXChildVisit_Recurse;

                    CXFile file;
                    unsigned start_line, start_column, start_offset;
                    unsigned end_line, end_column, end_offset;

                    thiz->clang->getExpansionLocation(thiz->clang->getRangeStart(cursorRange), &file, &start_line, &start_column, &start_offset);
                    thiz->clang->getExpansionLocation(thiz->clang->getRangeEnd(cursorRange), &file, &end_line, &end_column, &end_offset);

                    // Recurse through the tree until we find the current line, store the tailAnchor and break.
                    if (thiz->clang->Cursor_isNull(thiz->deepestParent)) {
                        if (thiz->line >= start_line && thiz->line <= end_line) {
                            thiz->deepestParent = c;
                        }
                    }

                    if (!thiz->clang->Cursor_isNull(thiz->deepestParent)) {
                        ret = CXChildVisit_Continue;
                    }

                    CXCursor lexicalParent = thiz->clang->getCursorLexicalParent(c);
                    thiz->addDecl(c, lexicalParent, thiz->clang);

                    return ret;
                }, this);

            this->anchorTrail.clear();
            this->deepestParent = this->clang->getNullCursor();
            this->rootCursor = this->clang->getNullCursor();
            this->clang->disposeTranslationUnit(unit);
        }

        this->clang->disposeIndex(index);
    }

    {
        QMutexLocker<QMutex> locker(&declsMutex);
        this->m_decls = m_declsInProgress;
        emit declsChanged();
    }

    {
        QMutexLocker<QMutex> locker(&clangMutex);
        this->clang = nullptr;
    }
}

void AutoCompleter::addDecl(CXCursor c, CXCursor parent, ClangWrapper* clang)
{
    CXCursorKind kind = clang->getCursorKind(c);
    CXCursorKind parentKind = clang->getCursorKind(parent);

    CXType cursorType = clang->getCursorType(c);
    CXString typeSpelling = clang->getTypeSpelling(cursorType);
    const QString prefix = QString::fromUtf8(clang->getCString(typeSpelling));
    clang->disposeString(typeSpelling);

    QString detail;
    if (!clang->equalCursors(parent, this->rootCursor)) {
        CXString relationSpelling = clang->getCursorSpelling(parent);
        detail = QString::fromUtf8(clang->getCString(relationSpelling));
        clang->disposeString(relationSpelling);
    }

    CXString spelling = clang->getCursorSpelling(c);
    const QString name = QString::fromUtf8(clang->getCString(spelling));
    clang->disposeString(spelling);

    CompletionKind completionKind = getAutoCompleterKind(kind);

    if (this->referenceHints.length() != 0) {
        bool hintedResults = false;
        for (const auto& hint : this->referenceHints) {
            if (!prefix.toLower().contains(hint) &&
                !name.toLower().contains(hint) &&
                !detail.toLower().contains(hint))
                continue;
            hintedResults = true;
        }

        if (!hintedResults)
            return;
    }

    qDebug() << "Found kind:" << prefix << name << detail;
    foundKind(completionKind, prefix, name, detail);
}

void AutoCompleter::reloadAst(const QStringList paths, const QString hint, const CompletionKind filter, const int line, const int column)
{
    {
        QMutexLocker<QMutex> locker(&clangMutex);
        // AST reload in progress
        if (clang) {
            return;
        }
    }

    this->sourceFiles = paths;
    this->hint = hint;
    this->referenceHints = createHints(hint.toLower());
    this->line = line;
    this->column = column;
    this->foundLine = true;
    this->typeFilter = filter;

    m_thread.terminate();
    m_thread.start();
}

void AutoCompleter::setSysroot(const QString sysroot)
{
    this->m_sysroot = sysroot;
}

void AutoCompleter::setIncludePaths(const QStringList paths)
{
    this->m_includePaths = paths;
}

QVariantList AutoCompleter::filteredDecls(const QString str)
{
    qDebug() << "Filter:" << str;
    QVariantList ret;
    QMutexLocker<QMutex> locker(&declsMutex);

    for (const auto& decl : m_decls) {
        const auto declMap = decl.toMap();
        const auto declPrefix = declMap.value("prefix").toString();
        const auto declName = declMap.value("name").toString();
        const auto declKind = declMap.value("kind").value<AutoCompleter::CompletionKind>();
        if (declName == str) {
            ret.push_front(decl);
        } else if (declPrefix.toLower().contains(str.toLower()) ||
                   declName.toLower().contains(str.toLower())) {
            ret.push_back(decl);
        }
    }
    return ret;
}

void AutoCompleter::foundKind(CompletionKind kind, const QString prefix, const QString name, const QString detail)
{
    if (name.isEmpty())
        return;

    if (this->typeFilter != CompletionKind::Unspecified) {
        if (kind == CompletionKind::Unspecified || !(this->typeFilter & kind)) {
            return;
        }
    }

    QVariantMap decl;
    decl.insert("prefix", prefix);
    decl.insert("name", name);
    decl.insert("detail", detail);
    decl.insert("kind", kind);

    for (const auto& decl : m_declsInProgress) {
        const auto declMap = decl.toMap();
        if (declMap.value("prefix").toString() == prefix &&
            declMap.value("name").toString() == name) {
            return;
        }
    }

    if (kind != AutoCompleter::CompletionKind::Unspecified) {
        m_declsInProgress.push_front(decl);
    } else {
        m_declsInProgress.push_back(decl);
    }
}
