#include "debugger.h"

#include <QDebug>
#include <QTimer>
#include <QVariant>
#include <QTemporaryFile>

#include <unistd.h>
#include <poll.h>

Debugger::Debugger(QObject *parent)
    : QObject{parent}, m_runner{nullptr}, m_system{nullptr}
{
    // Similar to Console
    QObject::connect(&m_readThreadOut, &QThread::started, this, &Debugger::readOutput, Qt::DirectConnection);
    QObject::connect(&m_readThreadErr, &QThread::started, this, &Debugger::readError, Qt::DirectConnection);

    // Debugger thread launching lldb
    QObject::connect(&m_debugThread, &QThread::started, this, &Debugger::runDebugSession, Qt::DirectConnection);

    // Keep lldb connection alive
    m_kea.setInterval(1000);
    m_kea.setSingleShot(false);
    QObject::connect(&m_kea, &QTimer::timeout, this, [=](){
        writeToStdIn("\n");
    });
}

void Debugger::read(FILE* io)
{
    qDebug() << Q_FUNC_INFO << io;
    char buffer[4096];
    memset(buffer, 0, 4096);
    while (::read(fileno(io), buffer, 1024))
    {
        const auto wholeOutput = QString::fromUtf8(buffer);
        const QStringList splitOutput = wholeOutput.split('\n', Qt::KeepEmptyParts);
        for (const auto& output : splitOutput) {
            qDebug() << "LLDB:" << output;
        }
        memset(buffer, 0, 4096);
        if (!m_running)
            return;
    }
}

void Debugger::readOutput()
{
    read(m_comm.stdout);
}

void Debugger::readError()
{
    read(m_comm.stderr);
}

void Debugger::debug(const QString binary, const QStringList args)
{
    if (!m_runner) {
        qWarning() << "No runner assigned, cannot debug.";
        return;
    }

    if (!m_system) {
        qWarning() << "No SystemGlue assigned, cannot debug.";
        return;
    }

    // Quit current debugger session
    quitDebugger();
    
    QObject::disconnect(m_runner, nullptr, nullptr, nullptr);

    QObject::connect(m_runner, &WasmRunner::debugSessionStarted, this, [=](int port){
            m_port = port;
            m_debugThread.start();
            m_running = true;
            emit runningChanged();
        }, Qt::QueuedConnection);

    QObject::connect(m_runner, &WasmRunner::runEnded, this, [=](int){
            m_kea.stop();
            quitDebugger();
        }, Qt::QueuedConnection);

    m_binary = binary;
    m_args = args;
    
    m_kea.start();
    m_runner->debug(m_binary, m_args);
}

void Debugger::addBreakpoint(const QString& breakpoint)
{
    if (m_breakpoints.contains(breakpoint)) {
        return;
    }

    m_breakpoints.push_back(breakpoint);
    emit breakpointsChanged();

    if (m_running) {
        const auto input = QByteArrayLiteral("b ") + breakpoint.toUtf8() + QByteArrayLiteral("\n");
        writeToStdIn(input);
    }
}

void Debugger::removeBreakpoint(const QString& breakpoint)
{
    if (!m_breakpoints.contains(breakpoint)) {
        return;
    }

    m_breakpoints.removeAll(breakpoint);
    emit breakpointsChanged();

    if (m_running) {
        const auto input = QByteArrayLiteral("d ") + breakpoint.toUtf8() + QByteArrayLiteral("\n");
        writeToStdIn(input);
    }
}

bool Debugger::hasBreakpoint(const QString& breakpoint)
{
    return m_breakpoints.contains(breakpoint);
}

void Debugger::runDebugSession()
{
    if (!m_system)
        return;

    QTemporaryFile tmpFile;
    if (!tmpFile.open()) {
        qWarning() << "Failed to create file for lldb batch script";
        return;
    }

    auto debugCommand =
        QStringLiteral("platform select remote-wasm-server\n") +
        QStringLiteral("process connect -p wasm connect://127.0.0.1:%1\n").arg(m_port);

    for (const auto& breakpoint : m_breakpoints) {
        debugCommand += QStringLiteral("b %1\n").arg(breakpoint);
    }

    debugCommand +=
        QStringLiteral("process continue\n") +
        QStringLiteral("frame variable\n");

    tmpFile.write(debugCommand.toUtf8());
    tmpFile.close();

    const QStringList cmds { QStringLiteral("lldb -S \"%1\"").arg(tmpFile.fileName()) };

    auto stdioPair = IosSystemGlue::setupPipes();
    m_comm = stdioPair.second;

    m_readThreadOut.start();
    m_readThreadErr.start();

    m_system->runBuildCommands(cmds, stdioPair.first);

    m_running = false;
    emit runningChanged();

    m_readThreadOut.quit();
    m_readThreadErr.quit();
    m_readThreadOut.wait();
    m_readThreadErr.wait();
}

void Debugger::writeToStdIn(const QByteArray& input)
{
    if (!m_comm.stdin)
        return;

    fwrite(input.data(), sizeof(char), input.length(), m_comm.stdin);
    fflush(m_comm.stdin);
}

void Debugger::stepIn()
{
    writeToStdIn("step-in\n");
}

void Debugger::stepOut()
{
    writeToStdIn("step-out\n");
}

void Debugger::stepOver()
{
    writeToStdIn("step-over\n");
}

void Debugger::pause()
{
    writeToStdIn("process interrupt\n");
}

void Debugger::cont()
{
    writeToStdIn("process continue\n");
}

void Debugger::quitDebugger()
{
    m_kea.stop();
    writeToStdIn("quit\n");
}
