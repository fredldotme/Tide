#ifndef SYNTAXHIGHLIGHTER_H
#define SYNTAXHIGHLIGHTER_H

#include <QObject>
#include <QQuickTextDocument>

#include "qsourcehighliter.h"

class SyntaxHighlighter : public QObject
{
    Q_OBJECT
public:
    explicit SyntaxHighlighter(QObject *parent = nullptr);

public slots:
    void init(QQuickTextDocument* doc, const bool lightTheme);
    void setCurrentLanguage(QSourceHighliter::Language language);

private:
    QSourceHighliter* m_highlighter;
};

#endif // SYNTAXHIGHLIGHTER_H
