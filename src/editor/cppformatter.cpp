#include "cppformatter.h"

#include <QDebug>

#include <clang/Basic/FileManager.h>
#include <clang/Basic/Diagnostic.h>
#include <clang/Basic/DiagnosticIDs.h>
#include <clang/Basic/SourceManager.h>
#include <clang/Format/Format.h>

using namespace clang;

CppFormatter::CppFormatter(QObject *parent)
    : QObject{parent}
{

}

QString CppFormatter::format(QString text, FormattingStyle formatStyle)
{
    QString ret;
    QByteArray buffer = text.toUtf8();
    format::FormatStyle style;

    switch (formatStyle) {
    case LLVM:
        style = format::getLLVMStyle(format::FormatStyle::LK_Cpp);
        break;
    case Google:
        style = format::getGoogleStyle(format::FormatStyle::LK_Cpp);
        break;
    case Chromium:
        style = format::getChromiumStyle(format::FormatStyle::LK_Cpp);
        break;
    default:
        qWarning() << "No known format style? Defaulting to LLVM";
        style = format::getLLVMStyle(format::FormatStyle::LK_Cpp);
        break;
    }

    auto range = clang::tooling::Range(0, buffer.size());

    auto includeReplaces = format::sortIncludes(style, buffer.data(), {range}, "<stdin>");
    auto codeReplaces = reformat(style, buffer.data(), range);

    auto replaces = includeReplaces.merge(codeReplaces);
    auto result = applyAllReplacements(buffer.data(), replaces);

    if (!result) {
        qWarning() << "Formatted garbage, returning original";
        emit formatError();
        return text;
    }

    return result.get().c_str();
}
