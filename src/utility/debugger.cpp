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
static const auto filterCallStackRegex = QRegularExpression("^(   |  \\*) frame #(\\d): ((.*)\\`(.*) at (.*)|(.*))");
static const auto filterStackFrameRegex = QRegularExpression("^\\((.*)\\) ([^=]*) = (.*)");
static const auto filterStackFrameInstructions = QRegularExpression("^(->  )(.*): (.*) (.*)");
static const auto filterFileStrRegex = QRegularExpression("^(.*):(\\d*)");

Debugger::Debugger(QObject *parent)
    : QObject{parent}, m_spawned{false}, m_running{false}, m_runner{nullptr}, m_system{nullptr}, m_forceQuit{false}
{
    // Similar to Console
    QObject::connect(&m_readThreadOut, &QThread::started, this, &Debugger::readOutput, Qt::DirectConnection);
    QObject::connect(&m_readThreadErr, &QThread::started, this, &Debugger::readError, Qt::DirectConnection);
    QObject::connect(&m_debuggerThread, &QThread::started, this, &Debugger::runDebugSession, Qt::DirectConnection);

    QObject::connect(this, &Debugger::breakpointsChanged, this, &Debugger::waitingpointsChanged);
    QObject::connect(this, &Debugger::watchpointsChanged, this, &Debugger::waitingpointsChanged);

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
    writeToStdIn("quit\n");

    close(fileno(m_stdioPair.second.stdout));
    close(fileno(m_stdioPair.second.stderr));

    m_readThreadOut.quit();
    m_readThreadErr.quit();
    m_debuggerThread.quit();

    m_readThreadOut.wait();
    m_readThreadErr.wait();
    m_debuggerThread.wait();
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

    ::setvbuf(io, nullptr, _IOLBF, 4096);

    while (select(1, &rfds, NULL, NULL, &tv) != -1) {
        if (!m_spawned || m_forceQuit)
            return;

        while (::read(fileno(io), buffer, 4096))
        {
            const auto wholeOutput = QString::fromUtf8(buffer);
            const QStringList splitOutput = wholeOutput.split('\n', Qt::KeepEmptyParts);

            if (io == m_stdioPair.second.stdout) {
                QVariantMap varmap;
                bool multiLineValues = false;

                auto appendToValue = [=](const QString val, QVariantMap& variantMap) {
                    const auto oldVal = variantMap.value("value");
                    const auto newVal = oldVal.toString() + QStringLiteral(" ") + val;
                    variantMap.insert("value", newVal);
                };

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
                        emit processContinued();
                        continue;
                    }

                    if (output.contains("stop reason = breakpoint")) {
                        emit hintPauseMessage();
                        continue;
                    }

                    if (multiLineValues) {
                        appendToValue(output.trimmed(), varmap);

                        // Go on until the end is reached
                        if (output != QStringLiteral("}"))
                            continue;
                    }
                    // Go on until the end is reached
                    else if (output == QStringLiteral("}")) {
                        // Fall through to multi-value insertion
                    } else if (!filterCallStackRegex.match(output).hasMatch() && (
                                   stackFrameRegex.match(output).hasMatch() ||
                                   filterStackFrameInstructions.match(output).hasMatch())) {
                        varmap = filterStackFrame(output);

                        // If this is a complex structure we need to continue at the next line
                        if (output.endsWith(" = {")) {
                            multiLineValues = true;
                            continue;
                        }
                        // Otherwise fall through to insertion
                    } else if (filterCallStackRegex.match(output).hasMatch()) {
                        varmap = filterCallStack(output);
                        QMutexLocker locker(&m_backtraceMutex);
                        if (!varmap.isEmpty()) {
                            bool hasIndex = false;
                            for (const auto& btentry : m_backtrace) {
                                if (varmap.value("frameIndex").toString() == btentry.toMap().value("frameIndex").toString()) {
                                    hasIndex = true;
                                    break;
                                }
                            }
                            if (!hasIndex) {
                                m_backtrace.append(varmap);
                                emit backtraceChanged();
                            }
                        }

                        // Continue here to leave the bottom for multi-line values
                        continue;
                    }

                    // Insert from here for multi-line value support
                    {
                        QMutexLocker locker(&m_valuesMutex);
                        if (!varmap.isEmpty() && !varmap.value("type").toString().trimmed().isEmpty() &&
                            !m_values.contains(varmap)) {
                            m_values.append(varmap);
                            emit valuesChanged();
                        }

                        multiLineValues = false;
                        varmap.clear();
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
        const auto fileStr = regexMatch.captured(6);
        const auto fileStrMatch = filterFileStrRegex.match(fileStr);
        const auto path = fileStrMatch.captured(1);
        const auto line = fileStrMatch.captured(2);
        const auto column = fileStrMatch.captured(3);
        const auto index = regexMatch.captured(2);
        const auto value = regexMatch.lastCapturedIndex() == 7 ?
                               regexMatch.captured(7) : regexMatch.captured(5);
        const auto pathCrumbs = path.split('/', Qt::SkipEmptyParts);
        const auto file = pathCrumbs.length() > 0 ? pathCrumbs.last() : "";
        const bool currentFrame = output.startsWith("  *");

        ret.insert("partial", false);
        ret.insert("path", path);
        ret.insert("file", file);
        ret.insert("line", line);
        ret.insert("column", column);
        ret.insert("currentFrame", currentFrame);
        ret.insert("frameIndex", index);
        ret.insert("value", value);

        if (currentFrame) {
            m_currentFile = path;
            m_currentLineOfExecution = fileStr;
            emit currentLineOfExecutionChanged();
        }
    }

    return ret;
}

QVariantMap Debugger::filterStackFrame(const QString output)
{
    QVariantMap ret;
    auto regexMatch = filterStackFrameRegex.match(output);
    auto regex2Match = filterStackFrameInstructions.match(output);
    qDebug() << Q_FUNC_INFO << regexMatch << "or" << regex2Match << "for input" << output;

    if (regexMatch.hasMatch()) {
        const auto type = regexMatch.captured(1);
        if (type.trimmed().isEmpty())
            return ret;

        ret.insert("partial", false);
        ret.insert("type", type);
        ret.insert("name", regexMatch.captured(2));
        ret.insert("value", regexMatch.captured(3));
    } else if (regex2Match.hasMatch()) {
        const auto type = regex2Match.captured(2);
        if (type.trimmed().isEmpty())
            return ret;

        ret.insert("partial", false);
        ret.insert("type", type);
        ret.insert("name", regex2Match.captured(3));
        ret.insert("value", regex2Match.captured(4));
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

void Debugger::addWatchpoint(const QString& watchpoint)
{
    if (m_watchpoints.contains(watchpoint)) {
        return;
    }

    m_watchpoints.push_back(watchpoint);
    emit watchpointsChanged();

    if (m_spawned) {
        const auto input = QByteArrayLiteral("watch set var -w write ") + watchpoint.toUtf8() + QByteArrayLiteral("\n");
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

void Debugger::removeWatchpoint(const QString& watchpoint)
{
    if (!m_watchpoints.contains(watchpoint)) {
        return;
    }

    m_watchpoints.removeAll(watchpoint);
    emit watchpointsChanged();

    if (m_spawned) {
        writeToStdIn("wa del\ny\n");
        for (const auto& valid_watchpoint : m_watchpoints) {
            const auto input = QByteArrayLiteral("watch set var -w write ") + valid_watchpoint.toUtf8() + QByteArrayLiteral("\n");
            writeToStdIn(input);
        }
    }
}

bool Debugger::hasBreakpoint(const QString& breakpoint)
{
    return m_breakpoints.contains(breakpoint);
}

bool Debugger::hasWatchpoint(const QString& watchpoint)
{
    return m_watchpoints.contains(watchpoint);
}

QVariantList Debugger::waitingpoints()
{
    QVariantList ret;
    for (const auto& breakpoint : m_breakpoints) {
        QVariantMap entry;
        entry.insert("value", breakpoint);
        entry.insert("type", "break");
        ret << entry;
    }
    for (const auto& watchpoint : m_watchpoints) {
        QVariantMap entry;
        entry.insert("value", watchpoint);
        entry.insert("type", "watch");
        ret << entry;
    }
    return ret;
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
        QStringLiteral("wa del\ny\n") +
        QStringLiteral("br del\ny\n") +
        QStringLiteral("settings set auto-one-line-summaries false\n") +
        QStringLiteral("platform select remote-linux\n") +
        QStringLiteral("process connect -p wasm connect://127.0.0.1:%1\n").arg(port);

    if (m_breakpoints.length() == 0) {
        debugCommand += QStringLiteral("b main\n");
    } else {
        for (const auto& breakpoint : m_breakpoints) {
            debugCommand += QStringLiteral("b %1\n").arg(breakpoint);
        }
    }

    for (const auto& watchpoint : m_watchpoints) {
        debugCommand += QStringLiteral("watch set var -w write %1\n").arg(watchpoint);
    }

    static bool inited = false;
    if (!inited) {
        debugCommand += QStringLiteral("target stop-hook add --one-liner \"frame variable\"\n");
        debugCommand += QStringLiteral("settings set frame-format frame #${frame.index}: ${frame.pc}{ ${module.file.basename}{\\`${function.name}}}{ at ${line.file.fullpath}:${line.number}}\\n\n");
        inited = true;
    }

    writeToStdIn(debugCommand.toUtf8());

    emit attachedToProcess();
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
    m_currentFile = "";
    m_currentLineOfExecution = "";
    emit currentLineOfExecutionChanged();

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

    m_currentFile = "";
    m_currentLineOfExecution = "";
    emit currentLineOfExecutionChanged();
    clearBacktrace();
    clearFrameValues();    
    quitDebugger();

    m_running = false;
    emit runningChanged();
    m_processPaused = false;
    emit processPausedChanged();
}

void Debugger::getBacktrace()
{
    clearBacktrace();
    writeToStdIn("bt all\n");
}

void Debugger::clearBacktrace()
{
    QMutexLocker locker(&m_backtraceMutex);
    qDebug() << "Clearing backtrace";
    m_backtrace.clear();
    emit backtraceChanged();
}

void Debugger::getFrameValues()
{
    clearFrameValues();
    writeToStdIn("frame variable\n");
}

void Debugger::clearFrameValues()
{
    QMutexLocker locker(&m_valuesMutex);
    qDebug() << "Clearing frame values";
    m_values.clear();
    emit valuesChanged();
}

void Debugger::getBacktraceAndFrameValues()
{
    clearBacktrace();
    clearFrameValues();
    writeToStdIn("bt all\nframe variable\n");
}

DirectoryListing Debugger::getFileForActiveLine()
{
    return DirectoryListing(DirectoryListing::File, m_currentFile);
}
