#ifndef LINENUMBERSHELPER_H
#define LINENUMBERSHELPER_H

#include <QObject>
#include <QQuickTextDocument>
#include <QTimer>

class LineNumberInfo : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int height MEMBER height NOTIFY heightChanged)

public:
    LineNumberInfo() {}

    void setHeight(int height) {
        if (height == this->height)
            return;
        this->height = height;
        emit heightChanged();
    }

    int height;

signals:
    void heightChanged();
};
Q_DECLARE_METATYPE(LineNumberInfo)

class LineNumbersHelper : public QObject
{
    Q_OBJECT

public:
    Q_PROPERTY(QObject* document READ document WRITE setDocument NOTIFY documentChanged)
    Q_PROPERTY(QVariantList lineCount MEMBER m_lineCount NOTIFY lineCountChanged)

    explicit LineNumbersHelper(QObject *parent = nullptr);

    Q_INVOKABLE bool isCurrentBlock(int blockNumber, int curserPosition);
    Q_INVOKABLE void delayedRefresh();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE quint64 currentLine(int cursorPosition);
    Q_INVOKABLE quint64 currentColumn(int cursorPosition);

    QObject* document();
    void setDocument(QObject* p);

private:
    int height(int lineNumber);
    QVariantList lineCount();

    QTimer m_delayedRefreshTimer;
    QVariantList m_lineCount;
    QQuickTextDocument* m_document = nullptr;

signals:
    void documentChanged();
    void lineCountChanged();

};

#endif // LINENUMBERSHELPER_H
