#ifndef IOSSYSTEMGLUE_H
#define IOSSYSTEMGLUE_H

#include <QObject>

#include "programspec.h"

class IosSystemGlue : public QObject
{
    Q_OBJECT

public:
    IosSystemGlue(QObject* parent = nullptr);

    Q_INVOKABLE bool runBuildCommands(const QStringList cmds);
    Q_INVOKABLE void killBuildCommands();
    Q_INVOKABLE void setupStdIo();

private:
    ProgramSpec m_spec;

signals:
    void stdioWritersPrepared(ProgramSpec spec);
    void stdioCreated(ProgramSpec spec);
    void commandEnded(int returnCode);
};

#endif // IOSSYSTEMGLUE_H
