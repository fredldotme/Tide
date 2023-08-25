#include "debugger.h"

#include <QDebug>
#include <QTimer>
#include <QVariant>
#include <QTemporaryFile>

Debugger::Debugger(QObject *parent)
    : QObject{parent}, m_runner{nullptr}, m_system{nullptr}
{
    QObject::connect(&m_debugThread, &QThread::started, this, &Debugger::runDebugSession, Qt::DirectConnection);
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

    QObject::disconnect(m_runner, nullptr, nullptr, nullptr);
    QObject::connect(m_runner, &WasmRunner::debugSessionStarted, this, [=](int port){
        m_port = port;
        m_debugThread.start();
    }, Qt::QueuedConnection);

    m_binary = binary;
    m_args = args;

    m_runner->debug(m_binary, m_args);
}

void Debugger::runDebugSession()
{
#if 0
    if (!m_system)
        return;

    QTemporaryFile tmpFile;
    if (!tmpFile.open()) {
        qWarning() << "Failed to create file for lldb batch script";
        return;
    }

    const auto debugCommand =
        QStringLiteral("platform select remote-linux\n") +
        QStringLiteral("gdb-remote %1\n").arg(m_port) +
        QStringLiteral("r\n");

    tmpFile.write(debugCommand.toUtf8());
    tmpFile.close();
    m_system->runDebugCommands(QStringLiteral("lldb --batch -s \"%1\"").arg(tmpFile.fileName()), {});
#endif
}
