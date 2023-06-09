#include "console.h"

#include <QDebug>

#include <unistd.h>
#include <poll.h>

Console::Console(QObject *parent) : QObject{parent}, m_quitting{false}
{
    QObject::connect(&m_readThreadOut, &QThread::started, this, &Console::readOutput, Qt::DirectConnection);
    QObject::connect(&m_readThreadErr, &QThread::started, this, &Console::readError, Qt::DirectConnection);
}

Console::~Console()
{
    m_quitting = true;

    close(fileno(m_spec.stdout));
    m_readThreadOut.terminate();
    m_readThreadOut.wait(1000);

    close(fileno(m_spec.stderr));
    m_readThreadErr.terminate();
    m_readThreadErr.wait(1000);
}

void Console::feedProgramSpec(StdioSpec spec)
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
    fflush(m_spec.stdin);
}

void Console::read(FILE* io)
{
    char buffer[4096];
    qDebug() << Q_FUNC_INFO << io;
    while (::read(fileno(io), buffer, 1024))
    {
        const auto wholeOutput = QString::fromUtf8(buffer);
        const QStringList splitOutput = wholeOutput.split('\n', Qt::KeepEmptyParts);
        for (const auto& output : splitOutput) {
            emit contentRead(output, (this->m_spec.stdout == io));
        }
        if (m_quitting)
            return;
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
