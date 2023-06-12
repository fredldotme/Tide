#include "formatter.h"

#include <string>
#include <iostream>

#include <clang/Format/Format.h>

using namespace clang;

class Formatter
{
public:
    enum FormattingStyle {
        LLVM = 0,
        Google,
        Chromium
    };

    explicit Formatter();

public:
    std::string format(std::string text, int formatStyle);
};

Formatter::Formatter()
{
}

std::string Formatter::format(std::string buffer, int formatStyle)
{
    using namespace clang;

    clang::format::FormatStyle style;

    if (buffer.empty()) {
        return buffer;
    }

    // Hack: Last character seems to get swallowed
    char lastCharacter = buffer[buffer.length() - 1];

    switch (formatStyle) {
    case LLVM:
        style = format::getLLVMStyle(clang::format::FormatStyle::LK_Cpp);
        break;
    case Google:
        style = format::getGoogleStyle(clang::format::FormatStyle::LK_Cpp);
        break;
    case Chromium:
        style = format::getChromiumStyle(clang::format::FormatStyle::LK_Cpp);
        break;
    default:
        std::cerr << "No known format style? Defaulting to LLVM" << std::endl;
        style = format::getLLVMStyle(clang::format::FormatStyle::LK_Cpp);
        break;
    }

    auto range = clang::tooling::Range(0, buffer.size());

    auto includeReplaces = format::sortIncludes(style, buffer.c_str(), {range}, "<stdin>");
    auto rangesAfterInclude = tooling::calculateRangesAfterReplacements(includeReplaces, {range});
    auto codeReplaces = format::reformat(style, buffer.c_str(), rangesAfterInclude);

    auto replaces = includeReplaces.merge(codeReplaces);
    auto result = applyAllReplacements(buffer.c_str(), replaces);

    if (!result) {
        std::cerr << "Formatted garbage, returning original" << std::endl;
        return buffer;
    }

    return result.get() + lastCharacter;
}

char* formatCode(const char* text, int style) {
    Formatter formatter;
    std::string formatted = formatter.format(text, style);

    if (formatted.length() == 0)
        return nullptr;

    char* ret = new char[formatted.length() + 1]();
    strlcpy(ret, (char*)formatted.data(), formatted.length());
    return ret;
}
