#include "linenumbershelper.h"

#include <QAbstractTextDocumentLayout>
#include <QDebug>
#include <QTextBlock>
#include <QQmlEngine>

LineNumbersHelper::LineNumbersHelper(QObject *parent) :
    QObject(parent), m_lineCount{0}
{

}

QObject* LineNumbersHelper::document()
{
    return this->m_document;
}

void LineNumbersHelper::setDocument(QObject *p)
{
    QQuickTextDocument* pointer = qobject_cast<QQuickTextDocument*>(p);

    if (!pointer) {
        qWarning() << "Provided pointer is not of type QQuickTextDocument";
        return;
    }

    if (this->m_document == pointer)
        return;

    if (this->m_document) {
        QObject::disconnect(this->m_document->textDocument(), nullptr, nullptr, nullptr);
    }

    this->m_document = pointer;

    QObject::connect(this->m_document->textDocument(), &QTextDocument::blockCountChanged,
                     this, [=](int count){
                         Q_UNUSED(count);
                         refresh();
                     }, Qt::QueuedConnection);
    QObject::connect(this->m_document->textDocument(), &QTextDocument::documentLayoutChanged,
                     this, &LineNumbersHelper::refresh, Qt::QueuedConnection);
    QObject::connect(this->m_document->textDocument(), &QTextDocument::contentsChanged,
                     this, &LineNumbersHelper::refresh, Qt::QueuedConnection);

    emit documentChanged();
}

void clearLineCount(QVariantList& list)
{
    while(!list.empty()) {
        auto newVar = list.takeLast();
        auto newInfo = newVar.value<LineNumberInfo*>();
        newInfo->deleteLater();
    }
}

void LineNumbersHelper::refresh()
{
    auto newLineCount = lineCount();

    if (this->m_lineCount.length() == newLineCount.length()) {
        for (int i = 0; i < newLineCount.length(); i++) {
            const auto& oldVar = this->m_lineCount.value(i);
            auto info = oldVar.value<LineNumberInfo*>();

            const auto& newVar = newLineCount.value(i);
            auto newInfo = newVar.value<LineNumberInfo*>();

            if (!newInfo || !info)
                continue;

            info->setHeight(newInfo->height);
        }

        clearLineCount(newLineCount);
        return;
    }

    auto oldLineCount = this->m_lineCount;
    this->m_lineCount = newLineCount;
    emit lineCountChanged();
    clearLineCount(oldLineCount);
}

QVariantList LineNumbersHelper::lineCount()
{
    QVariantList ret;

    if (!this->m_document)
        return ret;

    for (int line = 0; line < this->m_document->textDocument()->blockCount(); line++) {
        LineNumberInfo* info = new LineNumberInfo();

        QVariant var;
        info->setHeight(height(line));
        var.setValue(info);
        ret << var;
    }

    return ret;
}

int LineNumbersHelper::height(int lineNumber)
{
    if (!this->m_document)
        return 0;

    QTextBlock textBlock = this->m_document->textDocument()->findBlockByNumber(lineNumber);
    int ret = int(this->m_document->textDocument()->documentLayout()->blockBoundingRect(textBlock).height());
    return ret;
}

bool LineNumbersHelper::isCurrentBlock(int blockNumber, int curserPosition)
{
    if (!this->m_document)
        return false;

    QTextBlock block = this->m_document->textDocument()->findBlock(curserPosition);
    QTextBlock line = this->m_document->textDocument()->findBlockByNumber(blockNumber);
    return block == line;
}
