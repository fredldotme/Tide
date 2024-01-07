#include <tideplugin.h>

#include <string>
#include <iostream>

extern "C" {

class TidePluginHostInterface {};

struct TidePluginAutoCompleterResult {
    AutoCompletorKind kind;
    std::string type;
    std::string identifier;
    std::string detail;
    TidePluginAutoCompleterResult* next;
};

class TidePluginAutoCompleter : public TidePluginHostInterface {
public:
    bool setup(const std::string& contents);
    TidePluginAutoCompleterResult* find(const std::string& hint);    
};

static TidePluginAutoCompleterResult workingHint;
static TidePluginAutoCompleter globalAutoCompleter;

bool TidePluginAutoCompleter::setup(const std::string& contents)
{
    return true;
}

TidePluginAutoCompleterResult* TidePluginAutoCompleter::find(const std::string& hint)
{
    workingHint.kind = AutoCompletorKind::Variable;
    workingHint.type = "int";
    workingHint.identifier = "PluginWorking";
    workingHint.detail = "ExamplePlugin";
    workingHint.next = nullptr;
    return &workingHint;
}

TidePluginFeatures tide_plugin_features()
{
    return TidePluginFeatures::IDEAutoComplete;
}

const char* tide_plugin_name()
{
    return "ExamplePlugin";
}

const char* tide_plugin_description()
{
    return "Showcasing plugin integration into Tide";
}

TidePluginInterface tide_plugin_get_interface(const TidePluginFeatures feature)
{
    switch (feature) {
    case TidePluginFeatures::IDEAutoComplete:
        return static_cast<TidePluginInterface>(&globalAutoCompleter);
    default:
        return nullptr;
    }
}

bool tide_plugin_autocompletor_setup(TideAutoCompleter completer, const char* contents)
{
    auto autoCompleter = static_cast<TidePluginAutoCompleter*>(completer);
    if (!autoCompleter)
        return false;

    const auto result = autoCompleter->setup(std::string(contents));
    return result;
}

TideAutoCompleterResult tide_plugin_autocompletor_find(TideAutoCompleter completer,
                                                       const char* hint)
{
    auto autoCompleter = static_cast<TidePluginAutoCompleter*>(completer);
    if (!autoCompleter)
        return nullptr;

    const auto result = autoCompleter->find(std::string(hint));
    return static_cast<TideAutoCompleterResult>(result);
}

TideAutoCompleterResult tide_plugin_autocompletor_next(TideAutoCompleterResult result)
{
    if (!result)
        return nullptr;

    const auto res = static_cast<TidePluginAutoCompleterResult*>(result)->next;
    return static_cast<TideAutoCompleterResult>(res);
}

const AutoCompletorKind tide_plugin_autocompletorresult_kind(TideAutoCompleterResult result)
{
    if (!result)
        return AutoCompletorKind::Unspecified;

    const auto res = static_cast<TidePluginAutoCompleterResult*>(result);
    return res->kind;
}

const char* tide_plugin_autocompletorresult_type(TideAutoCompleterResult result)
{
    if (!result)
        return nullptr;

    const auto res = static_cast<TidePluginAutoCompleterResult*>(result);
    return res->type.c_str();
}

const char* tide_plugin_autocompletorresult_identifier(TideAutoCompleterResult result)
{
    if (!result)
        return nullptr;

    const auto res = static_cast<TidePluginAutoCompleterResult*>(result);
    return res->identifier.c_str();
}

const char* tide_plugin_autocompletorresult_detail(TideAutoCompleterResult result)
{
    if (!result)
        return nullptr;

    const auto res = static_cast<TidePluginAutoCompleterResult*>(result);
    return res->detail.c_str();
}

}
