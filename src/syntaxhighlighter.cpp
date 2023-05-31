#include "syntaxhighlighter.h"

SyntaxHighlighter::SyntaxHighlighter(QObject *parent)
    : QObject{parent}, m_highlighter(nullptr)
{

}

void SyntaxHighlighter::init(QQuickTextDocument* doc, const bool lightTheme)
{
    if (this->m_highlighter) {
        this->m_highlighter->setDocument(nullptr);
        delete this->m_highlighter;
        this->m_highlighter = nullptr;
    }

    if (lightTheme)
        this->m_highlighter = new QSourceHighliter(doc->textDocument());
    else
        this->m_highlighter = new QSourceHighliter(doc->textDocument(), QSourceHighliter::Monokai);
}
