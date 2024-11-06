#ifndef POSIXSYSTEMGLUE_H
#define POSIXSYSTEMGLUE_H

#include <QObject>
#include <QUrl>
#include <QRect>

#include "stdiospec.h"

struct Command {
    pid_t pid;
    StdioSpec stdio;
};

class PosixSystemGlue : public QObject
{
    Q_OBJECT

public:
    explicit PosixSystemGlue(QObject *parent = nullptr);
    ~PosixSystemGlue();

    StdioSpec consumerSpec();

    static std::pair<StdioSpec, StdioSpec> setupPipes();

    Command runCommand(const QString cmd, const StdioSpec spec = StdioSpec());
    int waitCommand(Command& cmd);
    void killCommand(Command& cmd);

    Q_INVOKABLE bool runBuildCommands(const QStringList cmds, const StdioSpec spec = StdioSpec());
    Q_INVOKABLE void killBuildCommands();
    Q_INVOKABLE void writeToStdIn(const QByteArray data);
    Q_INVOKABLE void setupStdIo();
    Q_INVOKABLE void copyToClipboard(const QString text);
    Q_INVOKABLE void share(const QString text, const QUrl url, const QRect pos);

private:
    StdioSpec m_spec;
    StdioSpec m_consumerSpec;

signals:
    void stdioWritersPrepared(StdioSpec spec);
    void stdioCreated(StdioSpec spec);
    void commandEnded(int returnCode);
};

#endif // POSIXSYSTEMGLUE_H
