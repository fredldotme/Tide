#ifndef POSIXSYSTEMGLUE_H
#define POSIXSYSTEMGLUE_H

#include <QObject>

class PosixSystemGlue : public QObject
{
    Q_OBJECT
public:
    explicit PosixSystemGlue(QObject *parent = nullptr);

public slots:
    bool runBuildCommands(const QStringList commands);
    void killBuildCommands();

signals:

};

#endif // POSIXSYSTEMGLUE_H
