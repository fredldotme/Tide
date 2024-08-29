#ifndef CONSOLE_H
#define CONSOLE_H

#include <QObject>
#include <QThread>

#include "stdiospec.h"

class Console : public QObject
{
    Q_OBJECT
public:
    explicit Console(QObject *parent = nullptr);
    ~Console();

    Q_INVOKABLE StdioSpec spec() { return m_spec; }

public slots:
    void feedProgramSpec(StdioSpec spec);
    void write(const QString str);

private:
    void read(FILE* io);
    void readOutput();
    void readError();

    QThread m_readThreadOut;
    QThread m_readThreadErr;
    StdioSpec m_spec;
    bool m_quitting;

signals:
    void contentRead(const QString line, const bool isStdout);
};

#endif // CONSOLE_H
