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
    const auto libPath = qApp->applicationDirPath() + "/Frameworks/Tide-Formatter.framework/Tide-Formatter";
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
