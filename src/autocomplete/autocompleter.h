#ifndef AUTOCOMPLETER_H
#define AUTOCOMPLETER_H

#include <QObject>
#include <QVariantMap>
#include <QThread>
#include <QList>

#include <vector>

#include "clangwrapper.h"

class AutoCompleter : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList decls MEMBER m_decls NOTIFY declsChanged)

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
    QStringList& referenceHints();
    const QStringList referenceHintsConst();
    void foundKind(CompletionKind kind, const QString prefix, const QString name, const QString detail);
    void addDecl(CXCursor c, CXCursor parent, ClangWrapper* clang);

    ClangWrapper* clang;
    CXCursor rootCursor;
    CXCursor deepestParent;
    int line;
    int column;
    bool foundLine;
    QList<CXCursor> anchorTrail;
    QList<QList<CXCursor>> anchorTrails;

public slots:
    void reloadAst(const QString path, const QString hint, const int line, const int column);
    void setSysroot(const QString sysroot);
    void setIncludePaths(const QStringList paths);
    QVariantList filteredDecls(const QString str);

private:
    void run();
    QStringList createHints(const QString& hint);

    QString m_path;
    QThread m_thread;
    QVariantList m_decls;
    QString m_sysroot;
    QStringList m_includePaths;
    QStringList m_referenceHints;
    QList<CompletionHint> m_anchorDecls;

signals:
    void declsChanged();
};

Q_DECLARE_METATYPE(AutoCompleter::CompletionHint)
Q_DECLARE_METATYPE(AutoCompleter)

#endif // AUTOCOMPLETER_H
