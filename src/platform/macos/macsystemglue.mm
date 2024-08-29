#include "macsystemglue.h"

#include <QCoreApplication>
#include <QDebug>
#include <QStandardPaths>
#include <QUrl>
#include <QProcess>
#include <QDesktopServices>
#include <QDir>

#include <thread>
#include <iostream>
#include <spawn.h>
#include <signal.h>

extern "C" {
#include <unistd.h>
}

#import <AppKit/AppKit.h>

extern char **environ;

MacSystemGlue::MacSystemGlue(QObject* parent) :
    QObject(parent), m_requestBuildStop{false}
{
    const auto currPath = qgetenv("PATH");
    const auto prefix = qApp->applicationDirPath() + QString(":");
    qputenv("PATH", prefix.toUtf8() + currPath);
}

MacSystemGlue::~MacSystemGlue()
{
    if (m_spec.std_out) {
        fwrite("\n", sizeof(char), 1, m_spec.std_out);
        fflush(m_spec.std_out);
    }

    if (m_spec.std_err) {
        fwrite("\n", sizeof(char), 1, m_spec.std_err);
        fflush(m_spec.std_err);
    }
}

StdioSpec MacSystemGlue::consumerSpec()
{
    return m_consumerSpec;
}

std::pair<StdioSpec, StdioSpec> MacSystemGlue::setupPipes()
{
    StdioSpec spec, consumerSpec;

    FILE* inWriteEnd = nullptr;
    FILE* outWriteEnd = nullptr;
    FILE* errWriteEnd = nullptr;

    FILE* inReadEnd = nullptr;
    FILE* outReadEnd = nullptr;
    FILE* errReadEnd = nullptr;

    int fdIn[2] = {0};
    int fdOut[2] = {0};
    int fdErr[2] = {0};

    pipe(fdIn);
    inReadEnd = fdopen(fdIn[0], "r");
    inWriteEnd = fdopen(fdIn[1], "w");

    pipe(fdOut);
    outReadEnd = fdopen(fdOut[0], "r");
    outWriteEnd = fdopen(fdOut[1], "w");

    pipe(fdErr);
    errReadEnd = fdopen(fdErr[0], "r");
    errWriteEnd = fdopen(fdErr[1], "w");

    setvbuf(inReadEnd , nullptr , _IOLBF , 1024);
    setvbuf(outWriteEnd , nullptr , _IOLBF , 1024);
    setvbuf(errWriteEnd , nullptr , _IOLBF , 1024);

    spec.std_in = inReadEnd;
    spec.std_out = outWriteEnd;
    spec.std_err = errWriteEnd;

    consumerSpec.std_in = inWriteEnd;
    consumerSpec.std_out = outReadEnd;
    consumerSpec.std_err = errReadEnd;

    return std::make_pair(spec, consumerSpec);
}

void MacSystemGlue::setupStdIo()
{
    auto pair = setupPipes();
    m_spec = pair.first;
    m_consumerSpec = pair.second;

    emit stdioWritersPrepared(m_spec);
    emit stdioCreated(m_consumerSpec);
}

static inline std::vector<std::string> split_command(const std::string& cmd)
{
    std::vector<std::string> cmd_parts;
    std::string tmp_part;

    std::string cmd_as_std(cmd);
    for (auto it = cmd_as_std.begin(); it != cmd_as_std.end(); it++) {
        if (*it == '\"') {
            while (++it != cmd_as_std.end() && *it != '\"') {
                tmp_part += *it;
            }
        } else if (*it == ' ') {
            if (tmp_part.size() != 0)
                cmd_parts.push_back(tmp_part);
            tmp_part = "";
        } else {
            tmp_part += *it;
        }
    }
    if (tmp_part.size() != 0)
        cmd_parts.push_back(tmp_part);

    return cmd_parts;
}

// Blocking and hence shouldn't be called from the main or GUI threads
bool MacSystemGlue::runBuildCommands(const QStringList cmds, const StdioSpec spec)
{
    for (const auto& command : cmds) {
        if (m_requestBuildStop)
            break;

        const auto res = runCommand(command, spec);

        if (res != 0) {
            qWarning() << "Build step failed with result" << res;
            return false;
        }
    }

    if (m_requestBuildStop) {
        m_requestBuildStop = false;
        return false;
    }
    return true;
}

// Blocking and hence shouldn't be called from the main or GUI threads
int MacSystemGlue::runCommand(const QString cmd, const StdioSpec spec)
{
    auto process = spawnProcess(cmd, spec, true);
    return process.exitCode;
}

void MacSystemGlue::killProcess(SystemGlueProcess process)
{
    kill(process.pid, SIGKILL);
}

SystemGlueProcess MacSystemGlue::spawnProcess(const QString cmd, const StdioSpec spec, const bool wait)
{
    SystemGlueProcess process;
    int status = 0;
    pid_t childpid = 0;
    int ret = -1;

    if (spec.std_in || spec.std_out || spec.std_err) {
        process.stdio.std_in = fdopen(dup(fileno(spec.std_in)), "r");
        process.stdio.std_out = fdopen(dup(fileno(spec.std_out)), "w");
        process.stdio.std_err = fdopen(dup(fileno(spec.std_err)), "w");
    } else {
        process.stdio.std_in = fdopen(dup(fileno(m_spec.std_in)), "r");
        process.stdio.std_out = fdopen(dup(fileno(m_spec.std_out)), "w");
        process.stdio.std_err = fdopen(dup(fileno(m_spec.std_err)), "w");
    }

    const auto stdcmd = cmd.toStdString();
    std::vector<std::string> args = split_command(stdcmd);
    std::vector<const char*> cargs;

    for (const auto& arg : args) {
        cargs.push_back(arg.c_str());
    }
    cargs.push_back(nullptr);

    if (cargs.size() == 1)
        goto done;

    posix_spawn_file_actions_t action;
    posix_spawn_file_actions_init(&action);
    posix_spawn_file_actions_addclose(&action, 0);
    posix_spawn_file_actions_addclose(&action, 1);
    posix_spawn_file_actions_addclose(&action, 2);
    posix_spawn_file_actions_adddup2(&action, fileno(process.stdio.std_in), 0);
    posix_spawn_file_actions_adddup2(&action, fileno(process.stdio.std_out), 1);
    posix_spawn_file_actions_adddup2(&action, fileno(process.stdio.std_err), 2);

    qDebug() << "Run command:" << cmd;

    status = posix_spawnp(&childpid, cargs[0], &action, NULL, (char * const*)cargs.data(), environ);
    if (status != 0) {
        qDebug() << "spawn status:" << status;
        ret = -1;
        goto done;
    }

    if (wait) {
        if (childpid >= 0) {
            waitpid(childpid, &status, 0);
        }
        ret = WEXITSTATUS(status);
    } else {
        ret = 255;
    }

done:
    posix_spawn_file_actions_destroy(&action);
    if (process.stdio.std_in)
        fclose(process.stdio.std_in);
    if (process.stdio.std_out)
        fclose(process.stdio.std_out);
    if (process.stdio.std_err)
        fclose(copy.std_err);

    process.exitCode = ret;
    return process;
}

void MacSystemGlue::killBuildCommands()
{
    m_requestBuildStop = true;
}

void MacSystemGlue::writeToStdIn(const QByteArray data)
{
    fwrite(data.constData(), sizeof(const char*), data.length(), m_consumerSpec.std_in);
    fflush(m_consumerSpec.std_in);
}

void MacSystemGlue::copyToClipboard(const QString text)
{
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:text.toNSString() forType:NSStringPboardType];
}

void MacSystemGlue::share(const QString text, const QUrl url, const QRect pos)
{
    qDebug() << Q_FUNC_INFO << url;

    if (!url.isValid())
        return;

    auto splitPath = url.path().split(QDir::separator(), Qt::SkipEmptyParts);
    if (splitPath.length() == 0)
        return;

    splitPath.takeLast();
    const auto fullPath = QStringLiteral("file:///") + splitPath.join(QDir::separator());
    qDebug() << "Opening:" << fullPath;
    QDesktopServices::openUrl(QUrl(fullPath));
}

