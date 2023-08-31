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

    StdioSpec consumerSpec();

    static std::pair<StdioSpec, StdioSpec> setupPipes();

    Q_INVOKABLE int runCommand(const QString cmd, const StdioSpec spec = StdioSpec());
    Q_INVOKABLE bool runBuildCommands(const QStringList cmds, const StdioSpec spec = StdioSpec());
    Q_INVOKABLE void killBuildCommands();
    Q_INVOKABLE void writeToStdIn(const QByteArray data);
    Q_INVOKABLE void setupStdIo();
    Q_INVOKABLE void copyToClipboard(const QString text);
    Q_INVOKABLE void share(const QString text, const QUrl url, const QRect pos);

    void changeDir(const QString path);

private:
    StdioSpec m_spec;
    StdioSpec m_consumerSpec;

signals:
    void stdioWritersPrepared(StdioSpec spec);
    void stdioCreated(StdioSpec spec);
    void commandEnded(int returnCode);
};

#endif // IOSSYSTEMGLUE_H
