#include "posixsystemglue.h"

#include <QDebug>

#include <unistd.h>

PosixSystemGlue::PosixSystemGlue(QObject *parent)
    : QObject{parent}
{

}

PosixSystemGlue::~PosixSystemGlue()
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

void PosixSystemGlue::setupStdIo()
{
    auto pair = setupPipes();
    m_spec = pair.first;
    m_consumerSpec = pair.second;

    emit stdioWritersPrepared(m_spec);
    emit stdioCreated(m_consumerSpec);
}

// Blocking and hence shouldn't be called from the main or GUI threads
bool PosixSystemGlue::runBuildCommands(const QStringList cmds, const StdioSpec spec)
{
    StdioSpec copy;

    if (spec.stdin || spec.stdout || spec.stderr) {
        copy.stdin = fdopen(dup(fileno(spec.stdin)), "r");
        copy.stdout = fdopen(dup(fileno(spec.stdout)), "w");
        copy.stderr = fdopen(dup(fileno(spec.stderr)), "w");
    } else {
        copy.stdin = fdopen(dup(fileno(m_spec.stdin)), "r");
        copy.stdout = fdopen(dup(fileno(m_spec.stdout)), "w");
        copy.stderr = fdopen(dup(fileno(m_spec.stderr)), "w");
    }

#if 0
    nosystem_stdin = copy.stdin;
    nosystem_stdout = copy.stdout;
    nosystem_stderr = copy.stderr;
#endif

    for (const auto& command : cmds) {
        const auto stdcmd = command.toStdString();
        const int ret = system(stdcmd.c_str());
        if (ret != 0)
            return false;
    }

    if (copy.stdin)
        fclose(copy.stdin);
    if (copy.stdout)
        fclose(copy.stdout);
    if (copy.stderr)
        fclose(copy.stderr);

    return true;
}

// Blocking and hence shouldn't be called from the main or GUI threads
int PosixSystemGlue::runCommand(const QString cmd, const StdioSpec spec)
{
    StdioSpec copy;

    if (spec.stdin || spec.stdout || spec.stderr) {
        copy.stdin = fdopen(dup(fileno(spec.stdin)), "r");
        copy.stdout = fdopen(dup(fileno(spec.stdout)), "w");
        copy.stderr = fdopen(dup(fileno(spec.stderr)), "w");
    } else {
        copy.stdin = fdopen(dup(fileno(m_spec.stdin)), "r");
        copy.stdout = fdopen(dup(fileno(m_spec.stdout)), "w");
        copy.stderr = fdopen(dup(fileno(m_spec.stderr)), "w");
    }

#if 0
    nosystem_stdin = copy.stdin;
    nosystem_stdout = copy.stdout;
    nosystem_stderr = copy.stderr;
#endif

    const auto stdcmd = cmd.toStdString();
    const int ret = system(stdcmd.c_str());
    qWarning() << "Return" << ret << "from command" << cmd;

    if (copy.stdin)
        fclose(copy.stdin);
    if (copy.stdout)
        fclose(copy.stdout);
    if (copy.stderr)
        fclose(copy.stderr);

    return ret;
}

void PosixSystemGlue::killBuildCommands()
{
}

void PosixSystemGlue::writeToStdIn(const QByteArray data)
{
    fwrite(data.constData(), sizeof(const char*), data.length(), m_consumerSpec.stdin);
    fflush(m_consumerSpec.stdin);
}

void PosixSystemGlue::copyToClipboard(const QString text)
{
}

void PosixSystemGlue::share(const QString text, const QUrl url, const QRect pos)
{
}
