#ifndef AUTOCOMPLETER_H
#define AUTOCOMPLETER_H

#include <QObject>
#include <QVariantMap>
#include <QThread>
#include <QList>

#include <vector>

#include "plugins/tidepluginmanager.h"

#include "clangwrapper.h"

class AutoCompleter : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList decls MEMBER m_decls NOTIFY declsChanged)
    Q_PROPERTY(TidePluginManager* pluginManager MEMBER m_pluginManager NOTIFY pluginManagerChanged)

public:
    enum CompletionKind {
        Unspecified = 0,
        Variable,
        Function,
        Struct,
        Union,
        Class,
        Enum,
        Field,
        Constant,
        Parameter
    };
    Q_ENUM(CompletionKind)

    struct CompletionHint {
        Q_GADGET
    public:
        QString prefix;
        QString name;
        QString detail;
        CompletionKind kind;
        CXCursor cursor; // Compared to in the second pass as the semantic parent
    };

    explicit AutoCompleter(QObject *parent = nullptr);
    void foundKind(CompletionKind kind, const QString prefix, const QString name, const QString detail);
    void addDecl(CXCursor c, CXCursor parent, ClangWrapper* clang);

    ClangWrapper* clang;
    CXCursor rootCursor;
    CXCursor deepestParent;
    int line;
    int column;
    bool foundLine;
    QStringList sourceFiles;
    QList<CXCursor> anchorTrail;
    QList<QList<CXCursor>> anchorTrails;
    QStringList referenceHints;
    QString hint;
    CompletionKind typeFilter;

public slots:
    void reloadAst(const QStringList path, const QString hint, const CompletionKind filter, const int line, const int column);
    void setSysroot(const QString sysroot);
    void setIncludePaths(const QStringList paths);
    QVariantList filteredDecls(const QString str);

private:
    void run();
    QStringList createHints(const QString& hint);

    QThread m_thread;
    QVariantList m_decls;
    QString m_sysroot;
    QStringList m_includePaths;
    QList<CompletionHint> m_anchorDecls;
    TidePluginManager* m_pluginManager;

signals:
    void declsChanged();
    void pluginManagerChanged();
};

Q_DECLARE_METATYPE(AutoCompleter::CompletionHint)
Q_DECLARE_METATYPE(AutoCompleter)

#endif // AUTOCOMPLETER_H
