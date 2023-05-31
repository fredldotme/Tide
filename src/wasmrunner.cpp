#include "wasmrunner.h"

#include <QDebug>
#include <QStandardPaths>

#include <iostream>
#include <fstream>

#include <unistd.h>

#include <wasm3.h>
#include <m3_api_wasi.h>
#include <m3_env.h>

typedef uint32_t wasm_ptr_t;
typedef uint32_t wasm_size_t;

constexpr uint32_t stack_size = 1048576;

static WasmRunner* g_wasmRunner = nullptr;

WasmRunner::WasmRunner(QObject *parent)
    : QObject{parent}, m_runtime(m_env.new_runtime(stack_size))
{
    g_wasmRunner = this;
    QObject::connect(&m_runThread, &QThread::started, this, &WasmRunner::executeInThread, Qt::DirectConnection);
}

#if 0
namespace wasm3 {
namespace detail {
template<> struct m3_type_to_sig<char *> : m3_sig<'s'> {};
template<> struct m3_type_to_sig<const char *> : m3_sig<'s'> {};
}
}
#endif

static M3Result SuppressLookupFailure (M3Result i_result)
{
    if (i_result == m3Err_functionLookupFailed)
        return m3Err_none;
    else
        return i_result;
}

m3ApiRawFunction(wasm3_print)
{
    m3ApiReturnType (uint32_t);

    m3ApiGetArgMem  (void*,           i_ptr);
    m3ApiGetArg     (wasm_size_t,     i_size);

    m3ApiCheckMem(i_ptr, i_size);

    qDebug() << Q_FUNC_INFO;
    const QString content = QString::fromRawData((QChar*)i_ptr, i_size);
    g_wasmRunner->printStatement(content);

    m3ApiReturn(i_size);
}

m3ApiRawFunction(wasm3_printf)
{
    m3ApiReturnType (int32_t);

    m3ApiGetArgMem  (const char*,    i_fmt);
    m3ApiGetArgMem  (wasm_ptr_t*,    i_args);

    qDebug() << Q_FUNC_INFO;

    if (m3ApiIsNullPtr(i_fmt)) {
        m3ApiReturn(0);
    }

    m3ApiCheckMem(i_fmt, 1);
    size_t fmt_len = strnlen(i_fmt, 1024);
    m3ApiCheckMem(i_fmt, fmt_len+1); // include `\0`

    QByteArray buf;
    buf.reserve(1024);
    const int length = sprintf(buf.data(), i_fmt, i_args);

    const QString content = QString::fromRawData((QChar*)buf.data(), length);
    g_wasmRunner->printStatement(content);

    m3ApiReturn(length);
}

class wasi_module: public wasm3::module
{
public:
    void link_wasi() {
        m3_LinkWASI(m_module.get());
        //SuppressLookupFailure(m3_LinkRawFunction(m_module.get(), "*", "_debug", "i(*i)", wasm3_print));
        //SuppressLookupFailure(m3_LinkRawFunction(m_module.get(), "*", "printf", "i(**)", wasm3_printf));
    }
};

void WasmRunner::executeInThread()
{
    try {
        m_runtime = m_env.new_runtime(stack_size);

        const QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
        const auto fullPath = dir + "/" + m_binary;

        std::ifstream wasm_file(fullPath.toUtf8().data(), std::ios::binary | std::ios::in);
        if (!wasm_file.is_open()) {
            throw std::runtime_error("Failed to open wasm file");
        }
        wasm3::module mod = m_env.parse_module(wasm_file);
        m_runtime.load(mod);

        /* hack, this should be upstreamed to wasm3_cpp.h */
        ((wasi_module*) &mod)->link_wasi();

        wasm3::function main_fn = m_runtime.find_function("main");
        auto res = main_fn.call<int>(m_binary.toUtf8().data(), m_args.data());
        std::cout << "result: " << res << std::endl;
    }
    catch(std::runtime_error &e) {
        std::cerr << "WASM3 error: " << e.what() << std::endl;
        emit errorOccured(e.what());
        return;
    }

    qDebug() << "Run successful";
}

void WasmRunner::run(const QString binary, const QStringList args)
{
    qDebug() << "Running" << binary;

    m_binary = binary;
    m_args = args;

    m_runThread.terminate();
    m_runThread.wait(1000);
    m_runThread.start();
}

void WasmRunner::kill()
{
    m_runThread.terminate();
    m_runThread.wait(1000);
    m_runtime = m_env.new_runtime(stack_size);
}

void WasmRunner::printStatement(QString content)
{
    qDebug() << Q_FUNC_INFO << content;
    emit printfReceived(content);
}

void WasmRunner::prepareStdio(ProgramSpec spec)
{
    m3_SetStreams(spec.stdin, spec.stdout, spec.stderr);
}
