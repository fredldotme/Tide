#ifndef CONSOLE_H
#define CONSOLE_H

#include <QObject>
#include <QThread>

#include "programspec.h"

class Console : public QObject
{
    Q_OBJECT
public:
    explicit Console(QObject *parent = nullptr);
    ~Console();

public slots:
    void feedProgramSpec(ProgramSpec spec);
    void write(const QString str);

private:
    void read(FILE* io);
    void readOutput();
    void readError();

    QThread m_readThreadOut;
    QThread m_readThreadErr;
    ProgramSpec m_spec;

signals:
    void contentRead(const QString line, const bool isStdout);
};

#endif // CONSOLE_H
