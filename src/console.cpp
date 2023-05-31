#include "console.h"

#include <QDebug>

#include <unistd.h>
#include <poll.h>

Console::Console(QObject *parent) : QObject{parent}
{
    QObject::connect(&m_readThreadOut, &QThread::started, this, &Console::readOutput, Qt::DirectConnection);
    QObject::connect(&m_readThreadErr, &QThread::started, this, &Console::readError, Qt::DirectConnection);
}

void Console::feedProgramSpec(ProgramSpec spec)
{
    m_spec.stdin = spec.stdin;
    m_spec.stdout = spec.stdout;
    m_spec.stderr = spec.stderr;

    m_readThreadOut.start(QThread::LowestPriority);
    m_readThreadErr.start(QThread::LowestPriority);
}

void Console::write(const QString str)
{
    if (!m_spec.stdin)
        return;

    fwrite(str.toUtf8().data(), sizeof(char), str.length(), m_spec.stdin);
}

void Console::read(FILE* io)
{
    char buffer[1024];
    qDebug() << Q_FUNC_INFO << io;
    while (fgets(buffer, 1024, io))
    {
        emit contentRead(QString::fromUtf8(buffer), (this->m_spec.stdout == io));
    }
}

void Console::readOutput()
{
    read(m_spec.stdout);
}

void Console::readError()
{
    read(m_spec.stderr);
}
