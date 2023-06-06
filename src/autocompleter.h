#ifndef AUTOCOMPLETER_H
#define AUTOCOMPLETER_H

#include <QObject>
#include <QVariantMap>
#include <QThread>

#include <vector>

#include "clangwrapper.h"

class AutoCompleter : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList decls MEMBER m_decls NOTIFY declsChanged)

public:
    enum CompletionKind {
        Unknown = 0,
        Variable,
        Function
    };
    Q_ENUM(CompletionKind)

    explicit AutoCompleter(QObject *parent = nullptr);
    void foundKind(CompletionKind kind, const QString name);

    ClangWrapper* clang;

public slots:
    void reloadAst(const QString path);
    void setIncludePaths(const QStringList paths);
    QVariantList filteredDecls(const QString str);

private:
    void run();

    QString m_path;
    QThread m_thread;
    QVariantList m_decls;
    QStringList m_includePaths;

signals:
    void declsChanged();
};

Q_DECLARE_METATYPE(AutoCompleter)

#endif // AUTOCOMPLETER_H
