#ifndef AUTOCOMPLETER_H
#define AUTOCOMPLETER_H

#include <QObject>
#include <QVariantMap>
#include <QThread>

#include <clang-c/Index.h>

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

public:
    explicit AutoCompleter(QObject *parent = nullptr);

public:
    void foundKind(CompletionKind kind, const QString name);

public slots:
    void reloadAst(const QString path);

private:
    void run();

    QString m_path;
    QThread m_thread;
    QVariantList m_decls;

signals:
    void declsChanged();
};

Q_DECLARE_METATYPE(AutoCompleter)

#endif // AUTOCOMPLETER_H
