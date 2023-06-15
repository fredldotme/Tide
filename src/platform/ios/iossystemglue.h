#ifndef IOSSYSTEMGLUE_H
#define IOSSYSTEMGLUE_H

#include <QObject>
#include <QRect>

#include "stdiospec.h"

class IosSystemGlue : public QObject
{
    Q_OBJECT

public:
    IosSystemGlue(QObject* parent = nullptr);
    ~IosSystemGlue();

    Q_INVOKABLE bool runBuildCommands(const QStringList cmds);
    Q_INVOKABLE void killBuildCommands();
    Q_INVOKABLE void setupStdIo();
    Q_INVOKABLE void copyToClipboard(const QString text);
    Q_INVOKABLE void share(const QString text, const QUrl url, const QRect pos);

private:
    StdioSpec m_spec;

signals:
    void stdioWritersPrepared(StdioSpec spec);
    void stdioCreated(StdioSpec spec);
    void commandEnded(int returnCode);
};

#endif // IOSSYSTEMGLUE_H
