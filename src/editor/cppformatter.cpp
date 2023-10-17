#include "cppformatter.h"

#include <QCoreApplication>
#include <QDebug>

#include <dlfcn.h>

CppFormatter::CppFormatter(QObject *parent)
    : QObject{parent}, handle{nullptr}
{
}

QString CppFormatter::format(QString text, FormattingStyle formatStyle)
{

#if defined(Q_OS_IOS)
    const auto libPath = qApp->applicationDirPath() + QStringLiteral("/Frameworks/Tide-Formatter.framework/Tide-Formatter");
#elif defined(Q_OS_MACOS)
    const auto libPath = qApp->applicationDirPath() + QStringLiteral("/../Frameworks/libTide-Formatter.dylib");
#else
    const auto libPath = qApp->applicationDirPath() + QStringLiteral("/../lib/libtide-Formatter.so");
#endif

    this->handle = dlopen(libPath.toUtf8().data(), RTLD_NOW | RTLD_LOCAL);

    if (!this->handle) {
        qWarning() << "Failed to load TideFormatter from" << libPath;
        emit formatError();
        return text;
    }

    *(void**)(&formatCode) = dlsym(this->handle, "formatCode");
    char* formattedCode = formatCode(text.toUtf8().data(), (int)formatStyle);
    dlclose(this->handle);
    this->handle = nullptr;

    if (!formattedCode) {
        emit formatError();
        return text;
    }

    QString ret = QString::fromUtf8(formattedCode, strlen(formattedCode));
    delete[] formattedCode;

    return ret;
}
