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

    close(fileno(m_spec.std_out));
    m_readThreadOut.terminate();
    m_readThreadOut.wait(1500);

    close(fileno(m_spec.std_err));
    m_readThreadErr.terminate();
    m_readThreadErr.wait(1500);
}

void Console::feedProgramSpec(StdioSpec spec)
{
    m_spec.std_in = spec.std_in;
    m_spec.std_out = spec.std_out;
    m_spec.std_err = spec.std_err;

    m_readThreadOut.start(QThread::LowestPriority);
    m_readThreadErr.start(QThread::LowestPriority);
}

void Console::write(const QString str)
{
    if (!m_spec.std_in)
        return;

    fwrite(str.toUtf8().data(), sizeof(char), str.length(), m_spec.std_in);
    fflush(m_spec.std_in);
}

void Console::read(FILE* io)
{
    qDebug() << Q_FUNC_INFO << io;

    int ret;
    fd_set rfds;
    struct timeval tv;
    char buffer[4096];
    memset(buffer, 0, 4096);

    FD_ZERO(&rfds);
    FD_SET(fileno(io), &rfds);
    tv.tv_sec = 1;
    tv.tv_usec = 0;

    ::setvbuf(io, nullptr, _IOLBF, 4096);

    while ((ret = select(1, &rfds, NULL, NULL, &tv)) != -1) {
        if (m_quitting)
            return;

        if (ret == 0)
            continue;

        while (::read(fileno(io), buffer, 4096))
        {
            const auto output = QString::fromUtf8(buffer);
            emit contentRead(output, (this->m_spec.std_out == io));
            memset(buffer, 0, 4096);
            if (m_quitting)
                return;
        }

        FD_ZERO(&rfds);
        FD_SET(fileno(io), &rfds);
        tv.tv_sec = 1;
        tv.tv_usec = 0;
    }
}

void Console::readOutput()
{
    read(m_spec.std_out);
}

void Console::readError()
{
    read(m_spec.std_err);
}
