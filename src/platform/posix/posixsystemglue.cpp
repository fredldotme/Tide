#include "posixsystemglue.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QStandardPaths>
#include <QUrl>
#include <QProcess>
#include <QDesktopServices>

#include <thread>

#include <sys/types.h>
#include <sys/wait.h>
#include <spawn.h>
#include <unistd.h>

PosixSystemGlue::PosixSystemGlue(QObject* parent) : QObject(parent)
{
    const auto currPath = qgetenv("PATH");
    const auto prefix = QString::fromUtf8(qgetenv("SNAP")) + QString("/usr/bin:");
    qputenv("PATH", prefix.toUtf8() + currPath);
}

PosixSystemGlue::~PosixSystemGlue()
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

StdioSpec PosixSystemGlue::consumerSpec()
{
    return m_consumerSpec;
}

std::pair<StdioSpec, StdioSpec> PosixSystemGlue::setupPipes()
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

void PosixSystemGlue::setupStdIo()
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
bool PosixSystemGlue::runBuildCommands(const QStringList cmds, const StdioSpec spec)
{
    bool ret = true;

    for (const auto& command : cmds) {
        if (runCommand(command, spec) != 0) {
            ret = false;
            break;
        }
    }

    return ret;
}

// Blocking and hence shouldn't be called from the main or GUI threads
int PosixSystemGlue::runCommand(const QString cmd, const StdioSpec spec)
{
    StdioSpec copy;
    int status;
    pid_t childpid, statuspid;
    int ret = -1;

    if (spec.std_in || spec.std_out || spec.std_err) {
        copy.std_in = fdopen(dup(fileno(spec.std_in)), "r");
        copy.std_out = fdopen(dup(fileno(spec.std_out)), "w");
        copy.std_err = fdopen(dup(fileno(spec.std_err)), "w");
    } else {
        copy.std_in = fdopen(dup(fileno(m_spec.std_in)), "r");
        copy.std_out = fdopen(dup(fileno(m_spec.std_out)), "w");
        copy.std_err = fdopen(dup(fileno(m_spec.std_err)), "w");
    }

    const auto stdcmd = cmd.toStdString();
    std::vector<std::string> args = split_command(stdcmd);
    std::vector<const char*> cargs;
    std::vector<char*> cenv;
    std::string cmdbin;
    posix_spawn_file_actions_t action;

    for (const auto& arg : args) {
        cargs.push_back(arg.c_str());
    }
    cargs.push_back(nullptr);

    if (cargs.size() == 1)
        goto done;

    posix_spawn_file_actions_init(&action);
    posix_spawn_file_actions_addclose(&action, 0);
    posix_spawn_file_actions_addclose(&action, 1);
    posix_spawn_file_actions_addclose(&action, 2);
    posix_spawn_file_actions_adddup2(&action, fileno(copy.std_in), 0);
    posix_spawn_file_actions_adddup2(&action, fileno(copy.std_out), 1);
    posix_spawn_file_actions_adddup2(&action, fileno(copy.std_err), 2);
    cmdbin = QStandardPaths::findExecutable(QString::fromStdString(args.at(0))).toStdString();

    if (cmdbin.empty()) {
        qWarning() << "Binary not found";
        goto done;
    }

    qDebug() << "Run command:" << cmd;
    qDebug() << "Using bin:" << QString::fromStdString(cmdbin);

    status = posix_spawn(&childpid, cmdbin.c_str(), &action, NULL, (char * const*)cargs.data(), environ);
    if (status != 0) {
        qDebug() << "spawn status:" << status;
        goto done;
    }

    if (childpid >= 0) {
        waitpid(childpid, &status, 0);
    }
    ret = WEXITSTATUS(status);

done:
    if (copy.std_in)
        fclose(copy.std_in);
    if (copy.std_out)
        fclose(copy.std_out);
    if (copy.std_err)
        fclose(copy.std_err);

    return ret;
}

void PosixSystemGlue::killBuildCommands()
{
}

void PosixSystemGlue::writeToStdIn(const QByteArray data)
{
    fwrite(data.constData(), sizeof(const char*), data.length(), m_consumerSpec.std_in);
    fflush(m_consumerSpec.std_in);
}

void PosixSystemGlue::copyToClipboard(const QString text)
{
}

void PosixSystemGlue::share(const QString text, const QUrl url, const QRect pos)
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
