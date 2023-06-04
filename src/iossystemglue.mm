#include "iossystemglue.h"

#include <QCoreApplication>
#include <QDebug>
#include <QStandardPaths>
#include <QUrl>

#include <thread>

extern "C" {
#include <ios_system/ios_system.h>
#include <ios_error.h>
}

IosSystemGlue::IosSystemGlue(QObject* parent) : QObject(parent)
{
    initializeEnvironment();
    joinMainThread = true;
    qputenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasi");
}

void IosSystemGlue::setupStdIo()
{
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

    m_spec.stdin = inReadEnd;
    m_spec.stdout = outWriteEnd;
    m_spec.stderr = errWriteEnd;

    emit stdioWritersPrepared({inReadEnd, outWriteEnd, errWriteEnd});
    emit stdioCreated({inWriteEnd, outReadEnd, errReadEnd});
}

// Blocking and hence shouldn't be called from the main or GUI threads
bool IosSystemGlue::runBuildCommands(const QStringList cmds)
{
    for (const auto& cmd : cmds) {
        thread_stdin = m_spec.stdin;
        thread_stdout = m_spec.stdout;
        thread_stderr = m_spec.stderr;

        const int ret = ios_system(cmd.toUtf8().data());
        emit commandEnded(ret);
        if (ret != 0)
            return false;
    }
    return true;
}

void IosSystemGlue::killBuildCommands()
{
    ios_kill();
}

