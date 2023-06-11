#ifndef CPPFORMATTER_H
#define CPPFORMATTER_H

#include <QObject>

class CppFormatter : public QObject
{
    Q_OBJECT
public:

    enum FormattingStyle {
        LLVM = 0,
        Google,
        Chromium
    };
    Q_ENUM(FormattingStyle);

    explicit CppFormatter(QObject *parent = nullptr);

public slots:
    QString format(QString text, FormattingStyle formatStyle);

signals:
    void formatError();
};

#endif // CPPFORMATTER_H
