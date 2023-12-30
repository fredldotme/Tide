#ifndef MACSYSTEMGLUE_H
#define MACSYSTEMGLUE_H

#include <QObject>
#include <QRect>

#include "stdiospec.h"

class MacSystemGlue : public QObject
{
    Q_OBJECT

public:
    MacSystemGlue(QObject* parent = nullptr);
    ~MacSystemGlue();

    StdioSpec consumerSpec();

    static std::pair<StdioSpec, StdioSpec> setupPipes();

    Q_INVOKABLE int runCommand(const QString cmd, const StdioSpec spec = StdioSpec());
    Q_INVOKABLE bool runBuildCommands(const QStringList cmds, const StdioSpec spec = StdioSpec());
    Q_INVOKABLE void killBuildCommands();
    Q_INVOKABLE void writeToStdIn(const QByteArray data);
    Q_INVOKABLE void setupStdIo();
    Q_INVOKABLE void copyToClipboard(const QString text);
    Q_INVOKABLE void share(const QString text, const QUrl url, const QRect pos);

private:
    StdioSpec m_spec;
    StdioSpec m_consumerSpec;
    bool m_requestBuildStop;

signals:
    void stdioWritersPrepared(StdioSpec spec);
    void stdioCreated(StdioSpec spec);
    void commandEnded(int returnCode);
};

#endif // MACSYSTEMGLUE_H
