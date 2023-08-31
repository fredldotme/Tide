#include "debugger.h"

#include <QDebug>
#include <QMutexLocker>
#include <QRegularExpression>
#include <QRegularExpressionMatch>
#include <QTimer>
#include <QVariant>
#include <QTemporaryFile>

#include <unistd.h>
#include <poll.h>
#include <signal.h>

static const auto stackFrameRegex = QRegularExpression("^(.*) (.*) = (.*)");
static const auto filterCallStackRegex = QRegularExpression("^(   |  \\*) frame #(\\d): (.*)");
static const auto filterStackFrameRegex = QRegularExpression("^\\((.*)\\) (.*) = (.*)");
static const auto filterFileStrRegex = QRegularExpression("^(.*):(\\d*):(\\d*)");

Debugger::Debugger(QObject *parent)
    : QObject{parent}, m_spawned{false}, m_running{false}, m_runner{nullptr}, m_system{nullptr}, m_forceQuit{false}
{
    // Similar to Console
    QObject::connect(&m_readThreadOut, &QThread::started, this, &Debugger::readOutput, Qt::DirectConnection);
    QObject::connect(&m_readThreadErr, &QThread::started, this, &Debugger::readError, Qt::DirectConnection);
    QObject::connect(&m_debuggerThread, &QThread::started, this, &Debugger::runDebugSession, Qt::DirectConnection);

    spawnDebugger();
}

void Debugger::spawnDebugger()
{
    if (m_spawned)
        return;

    m_stdioPair = SystemGlue::setupPipes();

    m_readThreadOut.start();
    m_readThreadErr.start();
    m_debuggerThread.start();
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
        if (!m_spawned || m_forceQuit)
            return;

        while (::read(fileno(io), buffer, 4096))
        {
            const auto wholeOutput = QString::fromUtf8(buffer);
            const QStringList splitOutput = wholeOutput.split('\n', Qt::KeepEmptyParts);

            if (io == m_stdioPair.second.stdout) {
                bool hasFrameValues = false;
                bool hasCallStack = false;

                for (const auto& output : splitOutput) {
                    if (output.isEmpty())
                        continue;

                    if (stackFrameRegex.match(output).hasMatch()) {
                        hasFrameValues = true;
                    } else if (filterCallStackRegex.match(output).hasMatch()) {
                        hasCallStack = true;
                    }
                }

                if (hasCallStack) {
                    clearBacktrace();
                }

                if (hasFrameValues) {
                    clearFrameValues();
                }

                for (const auto output : splitOutput) {
                    if (output.isEmpty())
                        continue;

                    qDebug() << "LLDB:" << output;

                    if (output.startsWith("Process") && output.endsWith("stopped")) {
                        m_processPaused = true;
                        emit processPausedChanged();
                        emit processPaused();
                        continue;
                    }

                    if (output.startsWith("Process") && output.endsWith("resuming")) {
                        m_processPaused = false;
                        emit processPausedChanged();
                        continue;
                    }

                    if (stackFrameRegex.match(output).hasMatch()) {
                        const QVariantMap varmap = filterStackFrame(output);
                        QMutexLocker locker(&m_valuesMutex);
                        if (!varmap.isEmpty())
                            m_values.append(varmap);
                        emit valuesChanged();
                    } else if (filterCallStackRegex.match(output).hasMatch()) {
                        const QVariantMap varmap = filterCallStack(output);
                        QMutexLocker locker(&m_backtraceMutex);
                        if (!varmap.isEmpty())
                            m_backtrace.append(varmap);
                        emit backtraceChanged();
                    }
                }
            }

            memset(buffer, 0, 4096);

            if (!m_spawned || m_forceQuit)
                return;
        }

        FD_ZERO(&rfds);
        FD_SET(fileno(io), &rfds);
        tv.tv_sec = 1;
        tv.tv_usec = 0;
    }
}

QVariantMap Debugger::filterCallStack(const QString output)
{
    QVariantMap ret;
    const auto regexMatch = filterCallStackRegex.match(output);
    qDebug() << Q_FUNC_INFO << regexMatch << "for input" << output;

    if (regexMatch.hasMatch()) {
        const auto fileStr = regexMatch.captured(4);
        const auto fileStrMatch = filterFileStrRegex.match(fileStr);
        const auto file = fileStrMatch.captured(1);
        const auto line = fileStrMatch.captured(2);
        const auto column = fileStrMatch.captured(3);
        const auto index = regexMatch.captured(2);
        const auto value = regexMatch.captured(3);

        ret.insert("partial", false);
        ret.insert("file", file);
        ret.insert("line", line);
        ret.insert("column", column);
        ret.insert("currentFrame", output.startsWith("  *"));
        ret.insert("frameIndex", index);
        ret.insert("value", value);
    }

    return ret;
}

QVariantMap Debugger::filterStackFrame(const QString output)
{
    QVariantMap ret;
    auto regexMatch = filterStackFrameRegex.match(output);
    qDebug() << Q_FUNC_INFO << regexMatch << "for input" << output;

    if (regexMatch.hasMatch()) {
        ret.insert("partial", false);
        ret.insert("type", regexMatch.captured(1));
        ret.insert("name", regexMatch.captured(2));
        ret.insert("value", regexMatch.captured(3));
    }

    return ret;
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

    m_binary = binary;
    m_args = args;

    m_runner->registerDebugger(this);
    m_runner->debug(m_binary, m_args);

    m_running = true;
    emit runningChanged();
}

void Debugger::addBreakpoint(const QString& breakpoint)
{
    if (m_breakpoints.contains(breakpoint)) {
        return;
    }

    m_breakpoints.push_back(breakpoint);
    emit breakpointsChanged();

    if (m_spawned) {
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

    if (m_spawned) {
        writeToStdIn("br del\ny\n");
        for (const auto& valid_breakpoint : m_breakpoints) {
            const auto input = QByteArrayLiteral("b ") + valid_breakpoint.toUtf8() + QByteArrayLiteral("\n");
            writeToStdIn(input);
        }
    }
}

bool Debugger::hasBreakpoint(const QString& breakpoint)
{
    return m_breakpoints.contains(breakpoint);
}

void Debugger::runDebugSession()
{
    const QString cmd { QStringLiteral("lldb") };

    m_spawned = true;
    const int ret = m_system->runCommand(cmd, m_stdioPair.first);
    qDebug() << "Debugger return value:" << ret;

    m_spawned = false;
}

void Debugger::writeToStdIn(const QByteArray& input)
{
    if (!m_stdioPair.second.stdin)
        return;

    // Always ensure a broken pipe cannot crash the app
    signal(SIGPIPE, SIG_IGN);

    fwrite(input.data(), sizeof(char), input.length(), m_stdioPair.second.stdin);
    fflush(m_stdioPair.second.stdin);
}

WasmRunner* Debugger::runner()
{
    return m_runner;
}

void Debugger::setRunner(WasmRunner* runner)
{
    if (runner == m_runner)
        return;

    if (m_runner)
        QObject::disconnect(m_runner, nullptr, nullptr, nullptr);

    m_runner = runner;

    if (m_runner) {
        QObject::connect(m_runner, &WasmRunner::runEnded, this, [=](int){
                quitDebugger();
            }, Qt::DirectConnection);
    }
}

SystemGlue* Debugger::system()
{
    return m_system;
}

void Debugger::setSystem(SystemGlue* system)
{
    if (m_system == system)
        return;

    m_system = system;
    if (!m_spawned)
        spawnDebugger();
}

void Debugger::connectToRemote(const int port)
{
    qDebug() << "Connecting to remote port" << port;

    spawnDebugger();

    auto debugCommand =
        QStringLiteral("process detach\n") +
        QStringLiteral("br del\ny\n") +
        QStringLiteral("platform select remote-linux\n") +
        QStringLiteral("process connect -p wasm connect://127.0.0.1:%1\n").arg(port);

    for (const auto& breakpoint : m_breakpoints) {
        debugCommand += QStringLiteral("b %1\n").arg(breakpoint);
    }

    static bool inited = false;
    if (!inited) {
        debugCommand += QStringLiteral("target stop-hook add --one-liner \"frame variable\"");
        inited = true;
    }

    writeToStdIn(debugCommand.toUtf8());

    emit attachedToProcess();
}

void Debugger::stepIn()
{
    writeToStdIn("thread step-in\n");
}

void Debugger::stepOut()
{
    writeToStdIn("thread step-out\n");
}

void Debugger::stepOver()
{
    writeToStdIn("thread step-over\n");
}

void Debugger::pause()
{
    writeToStdIn("process interrupt\n");
}

void Debugger::cont()
{
    writeToStdIn("process continue\n");
}

void Debugger::selectFrame(const int frame)
{
    const QString inputStr = QStringLiteral("frame select %1\n").arg(frame);
    writeToStdIn(inputStr.toUtf8());
}

void Debugger::quitDebugger()
{
    writeToStdIn("process detach\n");
}

void Debugger::killDebugger()
{
    if (!m_spawned)
        return;

    quitDebugger();

    m_running = false;
    emit runningChanged();
}

void Debugger::getBacktrace()
{
    writeToStdIn("bt\n");
}

void Debugger::clearBacktrace()
{
    QMutexLocker locker(&m_backtraceMutex);
    m_backtrace.clear();
    emit backtraceChanged();
}

void Debugger::getFrameValues()
{
    writeToStdIn("frame variable\n");
}

void Debugger::clearFrameValues()
{
    QMutexLocker locker(&m_valuesMutex);
    m_values.clear();
    emit valuesChanged();
}
