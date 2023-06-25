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
        Constant
    };
    Q_ENUM(CompletionKind)

    struct CompletionHint {
        Q_GADGET
    public:
        QString name;
        CompletionKind kind;
        CXCursor cursor; // Compared to in the second pass as the semantic parent
    };

    explicit AutoCompleter(QObject *parent = nullptr);
    QStringList& referenceHints();
    const QStringList referenceHintsConst();
    QList<CompletionHint>& currentAnchorDecls();
    const QList<CompletionHint> currentAnchorDeclsConst();
    void foundKind(CompletionKind kind, const QString name);

    ClangWrapper* clang;

public slots:
    void reloadAst(const QString path, const QString hint);
    void setIncludePaths(const QStringList paths);
    QVariantList filteredDecls(const QString str);

private:
    void run();
    QStringList createHints(const QString& hint);

    QString m_path;
    QThread m_thread;
    QVariantList m_decls;
    QStringList m_includePaths;
    QStringList m_referenceHints;
    QList<CompletionHint> m_anchorDecls;

signals:
    void declsChanged();
};

Q_DECLARE_METATYPE(AutoCompleter::CompletionHint)
Q_DECLARE_METATYPE(AutoCompleter)

#endif // AUTOCOMPLETER_H
