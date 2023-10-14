#include "wasmrunner.h"

#include <QObject>
#include <QCoreApplication>
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QString>

#include <cstring>
#include <iostream>
#include <fstream>
#include <cstdlib>

#include <unistd.h>
#include <stdio.h>
#include <signal.h>

#include "debugger.h"

#include <pthread.h>

#include "stdiospec.h"
#include "platform/systemglue.h"
#include "lib/wasmrunner/wasmrunner.h"


WasmRunner::WasmRunner(QObject *parent)
    : QObject{parent}, m_running{false}, m_system{nullptr}, m_debugger{nullptr},
    m_runnerHost{new TideWasmRunnerHost(this)}
{
}

WasmRunner::~WasmRunner()
{
}

void WasmRunner::signalStart()
{
    m_running = true;
    emit runningChanged();
}

void WasmRunner::signalEnd()
{
    if (!m_running)
        return;

    m_running = false;
    emit runningChanged();
    emit runEnded(sharedData.main_result);
}

static void* runInThread(void* userdata)
{
    WasmRunnerSharedData& shared = *static_cast<WasmRunnerSharedData*>(userdata);

    std::vector<std::string> args;
    std::vector<const char*> cargs;
    std::vector<const char*> env;

    args.push_back(shared.binary.toStdString());
    for (const auto& arg : shared.args) {
        args.push_back(arg.toStdString());
    }
    for (const auto& arg : args) {
        cargs.push_back(arg.c_str());
    }
    const auto mapping = QStringLiteral("/::/");

    qDebug() << "Start function" << shared.lib->start;
    shared.runner->signalStart();

    if (shared.lib->start) {
        qDebug() << "Executing using runtime " << shared.runtime;
        shared.lib->start(shared.runtime,
                          shared.binary.toStdString().c_str(),
                          cargs.size(),
                          (char**)cargs.data(),
                          dup(fileno(shared.stdio.stdin)),
                          dup(fileno(shared.stdio.stdout)),
                          dup(fileno(shared.stdio.stderr)),
                          shared.debug,
                          mapping.toStdString().c_str());
    }

    shared.runner->signalEnd();
    return nullptr;
}

void TideWasmRunnerHost::reportError(const std::string& err)
{
    emit runner->errorOccured(QString::fromStdString(err));
}

void TideWasmRunnerHost::reportExit(const int code)
{
    runner->sharedData.killing = true;
    if (runner->sharedData.debug && runner->sharedData.debugger) {
        runner->sharedData.debugger->killDebugger();
        runner->sharedData.debug = false;
    }
    emit runner->runEnded(code);
}

void TideWasmRunnerHost::reportDebugPort(const uint32_t port)
{
    qDebug() << "Received debug port:" << port;
    if (runner->sharedData.debugger) {
        runner->sharedData.debugger->connectToRemote(port);
    }
}

void WasmRunner::run(const QString binary, const QStringList args)
{
    start(binary, args, false);
}

void WasmRunner::debug(const QString binary, const QStringList args)
{
    start(binary, args, true);
}

void WasmRunner::waitForFinished()
{
    pthread_join(m_runThread, nullptr);
}

int WasmRunner::exitCode()
{
    return this->sharedData.main_result;
}

void WasmRunner::start(const QString binary, const QStringList args, const bool debug)
{
    kill();

    QString applicationFile = binary;
    {
        const QString aotPath = binary + QStringLiteral(".aot");
        if (QFile::exists(aotPath)) {
            QFileInfo aot(aotPath);
            QFileInfo wasm(binary);

            if (aot.lastModified() > wasm.lastModified())
                applicationFile = aotPath;
        }
    }

    qDebug() << "Running" << applicationFile << args << debug;

    sharedData.binary = applicationFile;
    sharedData.args = args;
    sharedData.main_result = -1;
    sharedData.system = m_system;
    sharedData.stdio = m_spec;
    sharedData.debug = debug;
    sharedData.debugger = m_debugger;
    sharedData.runner = this;


#ifdef Q_OS_IOS
    const auto libsRoot = qApp->applicationDirPath();
#else
    const auto libsRoot = qApp->applicationDirPath() + "/..";
#endif

    std::string runnerPath;
    if (m_forceDebugInterpreter || debug) {
        runnerPath = QStringLiteral("%1/Frameworks/Tide-Wasmrunner.framework/Tide-Wasmrunner").arg(libsRoot).toStdString();
    } else {
        runnerPath = QStringLiteral("%1/Frameworks/Tide-Wasmrunnerfast.framework/Tide-Wasmrunnerfast").arg(libsRoot).toStdString();
    }

    sharedData.lib = wamr_runtime_load(runnerPath.c_str());
    std::cout << "Loaded Wasmrunner " << sharedData.lib->handle << " from " << runnerPath << std::endl;

    if (sharedData.lib->init) {
        sharedData.runtime = sharedData.lib->init(m_runnerHost);
        std::cout << "Initialization complete: " << sharedData.runtime << std::endl;
    } else {
        sharedData.runtime = nullptr;
    }

    pthread_create(&m_runThread, nullptr, runInThread, &sharedData);
}

void WasmRunner::kill()
{
    sharedData.killing = true;
    if (sharedData.debug && m_debugger) {
        m_debugger->killDebugger();
        sharedData.debug = false;
    }

    stop(false);
}

void WasmRunner::stop(bool silent)
{
    if (sharedData.runtime) {
        if (sharedData.lib->stop) {
            sharedData.lib->stop(sharedData.runtime);
        }

        waitForFinished();

        if (sharedData.lib->destroy) {
            sharedData.lib->destroy(sharedData.runtime);
        }
        sharedData.runtime = nullptr;
    }

    if (!silent)
        signalEnd();
}

void WasmRunner::prepareStdio(StdioSpec spec)
{
    m_spec = spec;
    qDebug() << "stdio prepared";
}

void WasmRunner::registerDebugger(Debugger* debugger)
{
    m_debugger = debugger;
}

bool WasmRunner::running()
{
    return m_running;
}

