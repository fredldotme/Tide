#include "linenumbershelper.h"

#include <QAbstractTextDocumentLayout>
#include <QDebug>
#include <QTextBlock>

LineNumbersHelper::LineNumbersHelper(QObject *parent) : QObject(parent)
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
        QObject::disconnect(this->m_document->textDocument(), &QTextDocument::blockCountChanged,
                            this, &LineNumbersHelper::lineCountChanged);
    }

    this->m_document = pointer;
    QObject::connect(this->m_document->textDocument(), &QTextDocument::blockCountChanged,
                     this, &LineNumbersHelper::lineCountChanged);
    emit documentChanged();
}

int LineNumbersHelper::lineCount()
{
    if (!this->m_document)
        return 0;

    return this->m_document->textDocument()->blockCount();
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
