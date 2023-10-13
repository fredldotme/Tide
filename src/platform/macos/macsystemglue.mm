#include "macsystemglue.h"

#include <QCoreApplication>
#include <QDebug>
#include <QStandardPaths>
#include <QUrl>
#include <QProcess>

#include <thread>
#include <spawn.h>

extern "C" {
#include <unistd.h>
}

#import <AppKit/AppKit.h>

MacSystemGlue::MacSystemGlue(QObject* parent) : QObject(parent)
{
}

MacSystemGlue::~MacSystemGlue()
{
    if (m_spec.stdout) {
        fwrite("\n", sizeof(char), 1, m_spec.stdout);
        fflush(m_spec.stdout);
    }

    if (m_spec.stderr) {
        fwrite("\n", sizeof(char), 1, m_spec.stderr);
        fflush(m_spec.stderr);
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

    spec.stdin = inReadEnd;
    spec.stdout = outWriteEnd;
    spec.stderr = errWriteEnd;

    consumerSpec.stdin = inWriteEnd;
    consumerSpec.stdout = outReadEnd;
    consumerSpec.stderr = errReadEnd;

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
    StdioSpec copy;
    int status;
    pid_t childpid, statuspid;

    if (spec.stdin || spec.stdout || spec.stderr) {
        copy.stdin = fdopen(dup(fileno(spec.stdin)), "r");
        copy.stdout = fdopen(dup(fileno(spec.stdout)), "w");
        copy.stderr = fdopen(dup(fileno(spec.stderr)), "w");
    } else {
        copy.stdin = fdopen(dup(fileno(m_spec.stdin)), "r");
        copy.stdout = fdopen(dup(fileno(m_spec.stdout)), "w");
        copy.stderr = fdopen(dup(fileno(m_spec.stderr)), "w");
    }

    for (const auto& command : cmds) {
        const auto stdcmd = command.toStdString();
        const auto cmdcrumbs = command.split(' ', Qt::KeepEmptyParts);

        std::vector<std::string> args = split_command(stdcmd);
        std::vector<const char*> cargs;

        for (const auto& arg : args) {
            cargs.push_back(arg.c_str());
        }

        if (cmdcrumbs.length() == 0)
            continue;

        posix_spawn_file_actions_t action;
        posix_spawn_file_actions_init(&action);
        posix_spawn_file_actions_adddup2(&action, fileno(copy.stdin), 0);
        posix_spawn_file_actions_adddup2(&action, fileno(copy.stdout), 1);
        posix_spawn_file_actions_adddup2(&action, fileno(copy.stderr), 2);
        extern char **environ;

        const auto binpath = qApp->applicationDirPath() + "/" + cmdcrumbs[0];
        qDebug() << "Run build command:" << binpath;

        status = posix_spawn(&childpid, binpath.toLocal8Bit().data(), &action, NULL, (char**)cargs.data(), environ);
        statuspid = waitpid(childpid, &status, WUNTRACED | WCONTINUED);
        posix_spawn_file_actions_destroy(&action);

        if (statuspid == -1)
            return false;
        if (WEXITSTATUS(status) != 0)
            return false;
    }

done:
    if (copy.stdin)
        fclose(copy.stdin);
    if (copy.stdout)
        fclose(copy.stdout);
    if (copy.stderr)
        fclose(copy.stderr);

    return true;
}

// Blocking and hence shouldn't be called from the main or GUI threads
int MacSystemGlue::runCommand(const QString cmd, const StdioSpec spec)
{
    StdioSpec copy;
    int status;
    pid_t childpid, statuspid;
    int ret = -1;

    if (spec.stdin || spec.stdout || spec.stderr) {
        copy.stdin = fdopen(dup(fileno(spec.stdin)), "r");
        copy.stdout = fdopen(dup(fileno(spec.stdout)), "w");
        copy.stderr = fdopen(dup(fileno(spec.stderr)), "w");
    } else {
        copy.stdin = fdopen(dup(fileno(m_spec.stdin)), "r");
        copy.stdout = fdopen(dup(fileno(m_spec.stdout)), "w");
        copy.stderr = fdopen(dup(fileno(m_spec.stderr)), "w");
    }

    const auto stdcmd = cmd.toStdString();
    const auto cmdcrumbs = cmd.split(' ', Qt::KeepEmptyParts);

    std::vector<std::string> args = split_command(stdcmd);
    std::vector<const char*> cargs;
    std::vector<char*> cenv;

    for (const auto& arg : args) {
        cargs.push_back(arg.c_str());
    }

    if (cmdcrumbs.length() == 0)
        return ret;

    posix_spawn_file_actions_t action;
    posix_spawn_file_actions_init(&action);
    posix_spawn_file_actions_adddup2(&action, fileno(copy.stdin), 0);
    posix_spawn_file_actions_adddup2(&action, fileno(copy.stdout), 1);
    posix_spawn_file_actions_adddup2(&action, fileno(copy.stderr), 2);

    const auto binpath = qApp->applicationDirPath() + "/" + cmdcrumbs[0];
    qDebug() << "Run command:" << binpath;

    extern char **environ;
    status = posix_spawn(&childpid, binpath.toLocal8Bit().data(), &action, NULL, (char**)cargs.data(), environ);
    posix_spawn_file_actions_destroy(&action);
    statuspid = waitpid(childpid, &status, WUNTRACED | WCONTINUED);
    if (statuspid == -1) {
        return ret;
    }
    ret = WEXITSTATUS(status);

done:
    if (copy.stdin)
        fclose(copy.stdin);
    if (copy.stdout)
        fclose(copy.stdout);
    if (copy.stderr)
        fclose(copy.stderr);

    return ret;
}

void MacSystemGlue::killBuildCommands()
{
}

void MacSystemGlue::writeToStdIn(const QByteArray data)
{
    fwrite(data.constData(), sizeof(const char*), data.length(), m_consumerSpec.stdin);
    fflush(m_consumerSpec.stdin);
}

void MacSystemGlue::copyToClipboard(const QString text)
{
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:text.toNSString() forType:NSStringPboardType];
}

void MacSystemGlue::share(const QString text, const QUrl url, const QRect pos) {

}

