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

    explicit AutoCompleter(QObject *parent = nullptr);
    ~AutoCompleter();
    void foundKind(CompletionKind kind, const QString name);

    // Public because the child visitor needs those
    void* handle;
    CXIndex (*clang_createIndex)(int, int);
    CXTranslationUnit (*clang_createTranslationUnitFromSourceFile)(
        CXIndex, const char *, int,
        const char *const *, unsigned ,
        struct CXUnsavedFile *);
    CXCursor (*clang_getTranslationUnitCursor)(CXTranslationUnit);
    unsigned (*clang_visitChildren)(CXCursor,
                                    CXCursorVisitor,
                                    CXClientData);
    void (*clang_disposeTranslationUnit)(CXTranslationUnit);
    void (*clang_disposeIndex)(CXIndex);
    enum CXCursorKind (*clang_getCursorKind)(CXCursor);
    CXString (*clang_getCursorSpelling)(CXCursor);
    const char* (*clang_getCString)(CXString);
    void (*clang_disposeString)(CXString);

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
