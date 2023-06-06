#ifndef LINENUMBERSHELPER_H
#define LINENUMBERSHELPER_H

#include <QObject>
#include <QQuickTextDocument>

class LineNumbersHelper : public QObject
{
    Q_OBJECT

public:
    Q_PROPERTY(QObject* document READ document WRITE setDocument NOTIFY documentChanged)
    Q_PROPERTY(int lineCount READ lineCount NOTIFY lineCountChanged)

    explicit LineNumbersHelper(QObject *parent = nullptr);

    Q_INVOKABLE int lineCount();
    Q_INVOKABLE int height(int lineNumber);
    Q_INVOKABLE bool isCurrentBlock(int blockNumber, int curserPosition);

    QObject* document();
    void setDocument(QObject* p);

private:
    QQuickTextDocument* m_document = nullptr;

signals:
    void documentChanged();
    void lineCountChanged();

};

#endif // LINENUMBERSHELPER_H
