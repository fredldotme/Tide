#include "pyrunner.h"

#include <QObject>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QString>

#include <string>
#include <cstring>
#include <iostream>
#include <fstream>
#include <cstdlib>

#include <unistd.h>
#include <stdio.h>
#include <signal.h>

#include <pthread.h>

#include "stdiospec.h"
#include "platform/systemglue.h"

PyRunner::PyRunner(QObject *parent)
    : QObject{parent}, m_running{false}, m_isRepl{false}, m_system{nullptr}, m_runnerHost{new TidePyRunnerHost(this)}
{
}

PyRunner::~PyRunner()
{
}

void PyRunner::signalStart()
{
    m_running = true;
    emit runningChanged();
}

void PyRunner::signalEnd()
{
    if (!m_running)
        return;

    m_running = false;
    emit runningChanged();
    emit runEnded(sharedData.main_result);
}

static void* runInThread(void* userdata)
{
    PyRunnerSharedData& shared = *static_cast<PyRunnerSharedData*>(userdata);

    std::vector<std::string> args;
    std::vector<const char*> cargs;
    std::vector<const char*> env;

    const auto interpreterPath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                                 QStringLiteral("/Library/Python/bin/python-3.11.4.wasm");
    const auto pythonRootPath = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                                QStringLiteral("/Library/Python/usr");

    // Python interpreter as WASM binary
    args.push_back(interpreterPath.toStdString());

    // Python script to run
    if (shared.binary != "-")
        args.push_back(shared.binary.toStdString());
    else {
        args.push_back("-i");
    }

    for (const auto& arg : shared.args) {
        args.push_back(arg.toStdString());
    }
    for (const auto& arg : args) {
        cargs.push_back(arg.c_str());
    }

    qDebug() << "Start function" << shared.lib->start;
    shared.runner->signalStart();

    const auto mapping = QStringLiteral("/usr::") + pythonRootPath;
    qDebug() << "Mapping root to host dir:" << mapping;

    if (shared.lib->start) {
        qDebug() << "Executing using runtime " << shared.runtime;
        shared.lib->start(shared.runtime,
                          interpreterPath.toStdString().c_str(),
                          cargs.size(),
                          (char**)cargs.data(),
                          dup(fileno(shared.stdio.std_in)),
                          dup(fileno(shared.stdio.std_out)),
                          dup(fileno(shared.stdio.std_err)),
                          shared.debug,
                          mapping.toStdString().c_str());
    }

    shared.runner->signalEnd();
    return nullptr;
}

void TidePyRunnerHost::report(const std::string& msg)
{
    emit runner->message(QString::fromStdString(msg));
}

void TidePyRunnerHost::reportError(const std::string& err)
{
    emit runner->errorOccured(QString::fromStdString(err));
}

void TidePyRunnerHost::reportExit(const int code)
{
    runner->sharedData.killing = true;
#if 0
    if (runner->sharedData.debug && runner->sharedData.debugger) {
        runner->sharedData.debugger->killDebugger();
        runner->sharedData.debug = false;
    }
#endif
    emit runner->runEnded(code);
}

void TidePyRunnerHost::reportDebugPort(const uint32_t port)
{
#if 0
    qDebug() << "Received debug port:" << port;
    if (runner->sharedData.debugger) {
        runner->sharedData.debugger->connectToRemote(port);
    }
#endif
}

void PyRunner::run(const QString binary, const QStringList args)
{
    start(binary, args, false);
}

void PyRunner::debug(const QString binary, const QStringList args)
{
    start(binary, args, true);
}

void PyRunner::waitForFinished()
{
    std::lock_guard<std::mutex> lk(sharedData.runMutex);
    pthread_join(m_runThread, nullptr);
    sharedData.running = false;
}

int PyRunner::exitCode()
{
    return this->sharedData.main_result;
}

void PyRunner::start(const QString binary, const QStringList args, const bool debug)
{
    kill();

    QString applicationFile = binary;
    qDebug() << "Running" << applicationFile << args << debug;

    sharedData.binary = applicationFile;
    sharedData.args = args;
    sharedData.main_result = -1;
    sharedData.system = m_system;
    sharedData.stdio = m_spec;
    sharedData.debug = false;
    sharedData.runner = this;

    std::string runnerPath;

#ifdef Q_OS_IOS
    const auto libsRoot = qApp->applicationDirPath();
#elif defined(Q_OS_MACOS)
    const auto libsRoot = qApp->applicationDirPath() + "/..";
#elif defined(Q_OS_LINUX)
    const auto libsRoot = qApp->applicationDirPath() + "/../../lib";
#endif

#ifndef Q_OS_LINUX
    runnerPath = QStringLiteral("%1/Frameworks/Tide-Wasmrunnerfast.framework/Tide-Wasmrunnerfast").arg(libsRoot).toStdString();
#else
    runnerPath = QStringLiteral("%1/libtide-Wasmrunnerfast.so").arg(libsRoot).toStdString();
#endif

    sharedData.lib = wamr_runtime_load(runnerPath.c_str());
    std::cout << "Loaded Python Wasmrunner " << sharedData.lib->handle << " from " << runnerPath << std::endl;

    if (sharedData.lib->init) {
        WasmRunnerConfig config;
        const auto docs = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
        const auto mapping = QStringLiteral("%1::%2").arg(docs, docs).toStdString();
        const auto projectDir = QFileInfo(applicationFile).dir().absolutePath();
        const auto projectDirMapping = QStringLiteral("%1::%2").arg(projectDir, projectDir).toStdString();

        config.flags = WasmRunnerConfigFlags::None;
        config.mapDirs.push_back(mapping);
        config.mapDirs.push_back(projectDirMapping);
        config.heapSize = 256 * 1024 * 1024;
        config.stackSize = 16 * 1024 * 1024;

        sharedData.runtime = sharedData.lib->init(m_runnerHost, (WasmRuntimeConfig)&config);
        std::cout << "Initialization complete: " << sharedData.runtime << std::endl;
    } else {
        sharedData.runtime = nullptr;
    }

    m_isRepl = false;
    emit isReplChanged();

    std::lock_guard<std::mutex> lk(sharedData.runMutex);
    pthread_create(&m_runThread, nullptr, runInThread, &sharedData);
    sharedData.running = true;
}

void PyRunner::kill()
{
    sharedData.killing = true;
#if 0
    if (sharedData.debug && m_debugger) {
        m_debugger->killDebugger();
        sharedData.debug = false;
    }
#endif

    if (!m_running)
        return;

    stop(false);
}

void PyRunner::stop(bool silent)
{
    if (sharedData.running) {
        if (sharedData.runtime && sharedData.lib->stop) {
            sharedData.lib->stop(sharedData.runtime);
        }

        waitForFinished();

        if (sharedData.runtime && sharedData.lib->destroy) {
            sharedData.lib->destroy(sharedData.runtime);
        }
        sharedData.runtime = nullptr;
    }

    if (!silent)
        signalEnd();
}

void PyRunner::prepareStdio(StdioSpec spec)
{
    m_spec = spec;
    qDebug() << "stdio prepared";
}

void PyRunner::runRepl()
{
    kill();

    sharedData.binary = QStringLiteral("-");
    sharedData.args = QStringList();
    sharedData.main_result = -1;
    sharedData.system = m_system;
    sharedData.stdio = m_spec;
    sharedData.debug = false;
    sharedData.runner = this;

    std::string runnerPath;

#ifdef Q_OS_IOS
    const auto libsRoot = qApp->applicationDirPath();
#elif defined(Q_OS_MACOS)
    const auto libsRoot = qApp->applicationDirPath() + "/..";
#elif defined(Q_OS_LINUX)
    const auto libsRoot = qApp->applicationDirPath() + "/../lib";
#endif

#ifndef Q_OS_LINUX
    runnerPath = QStringLiteral("%1/Frameworks/Tide-Wasmrunnerfast.framework/Tide-Wasmrunnerfast").arg(libsRoot).toStdString();
#else
    runnerPath = QStringLiteral("%1/libtide-Wasmrunnerfast.so").arg(libsRoot).toStdString();
#endif

    sharedData.lib = wamr_runtime_load(runnerPath.c_str());
    std::cout << "Loaded Python Wasmrunner " << sharedData.lib->handle << " from " << runnerPath << std::endl;

    if (sharedData.lib->init) {
        WasmRunnerConfig config;
        config.flags = WasmRunnerConfigFlags::None;
        config.heapSize = 256 * 1024 * 1024;
        config.stackSize = 16 * 1024 * 1024;
        sharedData.runtime = sharedData.lib->init(m_runnerHost, (WasmRuntimeConfig)&config);
        std::cout << "Initialization complete: " << sharedData.runtime << std::endl;
    } else {
        sharedData.runtime = nullptr;
    }

    m_isRepl = true;
    emit isReplChanged();

    std::lock_guard<std::mutex> lk(sharedData.runMutex);
    pthread_create(&m_runThread, nullptr, runInThread, &sharedData);
    sharedData.running = true;
}

bool PyRunner::running()
{
    return m_running;
}

