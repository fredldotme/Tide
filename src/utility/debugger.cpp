#include "debugger.h"

#include <QDebug>
#include <QTimer>
#include <QVariant>
#include <QTemporaryFile>
#include <QRegularExpression>

#include <unistd.h>
#include <poll.h>
#include <signal.h>

static const QRegularExpression stackFrameRegex = QRegularExpression("^(.*) .* = .*");

Debugger::Debugger(QObject *parent)
    : QObject{parent}, m_runner{nullptr}, m_system{nullptr}, m_forceQuit{false}
{
    // Similar to Console
    QObject::connect(&m_readThreadOut, &QThread::started, this, &Debugger::readOutput, Qt::DirectConnection);
    QObject::connect(&m_readThreadErr, &QThread::started, this, &Debugger::readError, Qt::DirectConnection);
}

Debugger::~Debugger()
{
    m_forceQuit = true;
    m_readThreadOut.quit();
    m_readThreadErr.quit();
    m_readThreadOut.wait();
    m_readThreadErr.wait();
}

void Debugger::read(FILE* io)
{
    qDebug() << Q_FUNC_INFO << io;

    fd_set rfds;
    struct timeval tv;
    char buffer[4096];
    memset(buffer, 0, 4096);

    FD_ZERO(&rfds);
    FD_SET(fileno(io), &rfds);
    tv.tv_sec = 1;
    tv.tv_usec = 0;

    while (select(1, &rfds, NULL, NULL, &tv) != -1) {
        if (!m_running || m_forceQuit)
            return;

        while (::read(fileno(io), buffer, 4096))
        {
            const auto wholeOutput = QString::fromUtf8(buffer);
            const QStringList splitOutput = wholeOutput.split('\n', Qt::KeepEmptyParts);

            bool hasFrameValues = false;
            bool hasCallStack = false;

            if (io == m_stdioPair.second.stdout) {
                for (const auto& output : splitOutput) {
                    if (output.isEmpty())
                        continue;

                    if (stackFrameRegex.match(output).hasMatch()) {
                        hasFrameValues = true;
                    } else if (!output.startsWith("(lldb)")) {
                        hasCallStack = true;
                    }
                }

                if (hasCallStack) {
                    m_backtrace.clear();
                    emit backtraceChanged();
                }

                if (hasFrameValues) {
                    m_values.clear();
                    emit valuesChanged();
                }

                for (const auto output : splitOutput) {
                    if (output.isEmpty())
                        continue;

                    if (output == QStringLiteral("Process 1 stopped")) {
                        QTimer::singleShot(500, this, &Debugger::getBacktrace);
                        QTimer::singleShot(500, this, &Debugger::getFrameValues);
                        continue;
                    }

                    qDebug() << "LLDB:" << output;
                    if (stackFrameRegex.match(output).hasMatch()) {
                        QVariantMap varmap;
                        varmap.insert("value", output);
                        m_values.append(varmap);
                        emit valuesChanged();
                    } else if (!output.startsWith("(lldb)")) {
                        QVariantMap varmap;
                        varmap.insert("trace", output);
                        m_backtrace.append(varmap);
                        emit backtraceChanged();
                    }
                }
            }

            memset(buffer, 0, 4096);

            if (!m_running || m_forceQuit)
                return;
        }

        FD_ZERO(&rfds);
        FD_SET(fileno(io), &rfds);
        tv.tv_sec = 1;
        tv.tv_usec = 0;
    }
}

void Debugger::readOutput()
{
    read(m_stdioPair.second.stdout);
}

void Debugger::readError()
{
    read(m_stdioPair.second.stderr);
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

    // Kill previous current debugger session
    quitDebugger();

    static bool hasPair = false;
    if (!hasPair) {
        m_stdioPair = m_system->setupPipes();
        hasPair = true;
    }

    QObject::disconnect(m_runner, nullptr, nullptr, nullptr);

    QObject::connect(m_runner, &WasmRunner::debugSessionStarted, this, [=](int port){
            m_port = port;
            std::thread debugThread([=]() {
                runDebugSession();
            });
            debugThread.detach();
            m_running = true;
            emit runningChanged();
        }, Qt::QueuedConnection);

    QObject::connect(m_runner, &WasmRunner::runEnded, this, [=](int){
            quitDebugger();
        }, Qt::QueuedConnection);

    m_binary = binary;
    m_args = args;

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

    debugCommand += QStringLiteral("process continue\n");

    tmpFile.write(debugCommand.toUtf8());
    tmpFile.close();

    const QStringList cmds { QStringLiteral("lldb --debug -S \"%1\"").arg(tmpFile.fileName()) };

    m_readThreadOut.start();
    m_readThreadErr.start();

    qDebug() <<
        "m_stdioPair.first.stdin" << m_stdioPair.first.stdin <<
        "m_stdioPair.second.stdin" << m_stdioPair.second.stdin;

    signal(SIGPIPE, SIG_IGN);
    m_system->runBuildCommands(cmds, m_stdioPair.first);
    signal(SIGPIPE, SIG_IGN);

    m_forceQuit = true;
    m_running = false;
    emit runningChanged();
}

void Debugger::writeToStdIn(const QByteArray& input)
{
    if (!m_stdioPair.second.stdin)
        return;

    signal(SIGPIPE, SIG_IGN);
    fwrite(input.data(), sizeof(char), input.length(), m_stdioPair.second.stdin);
    fflush(m_stdioPair.second.stdin);
}

void Debugger::stepIn()
{
    writeToStdIn("step\n");
}

void Debugger::stepOut()
{
    writeToStdIn("finish\n");
}

void Debugger::stepOver()
{
    writeToStdIn("next\n");
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
    writeToStdIn("process detach\nquit\n");
}

void Debugger::killDebugger()
{
    signal(SIGPIPE, SIG_IGN);
    quitDebugger();
    m_forceQuit = true;

    m_running = false;
    emit runningChanged();
}

void Debugger::getBacktrace()
{
    m_backtrace.clear();
    emit backtraceChanged();

    const auto input = QByteArrayLiteral("bt\n");
    writeToStdIn(input);
}

void Debugger::getFrameValues()
{
    m_values.clear();
    emit valuesChanged();

    writeToStdIn("frame variable\n");
}
