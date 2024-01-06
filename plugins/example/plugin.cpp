#include <tideplugin.h>

#include <string>

struct TidePluginAutoCompleterResult {
    std::string type;
    std::string identifier;
    TidePluginAutoCompleterResult* next;
};

class TidePluginAutoCompleter : public TidePluginHostInterface {
public:
    TidePluginAutoCompleterResult* find(const std::string& hint);    
};

static TidePluginAutoCompleter globalAutoCompleter;

TidePluginAutoCompleterResult* TidePluginAutoCompleter::find(const std::string& hint)
{
    return nullptr;
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

TidePluginInterface tide_plugin_get_interface(const TidePluginFeatures& feature)
{
    switch (feature) {
    case TidePluginFeatures::IDEAutoComplete:
        return static_cast<TidePluginInterface>(&globalAutoCompleter);
    default:
        return nullptr;
    }
}

TideAutoCompleterResult tide_plugin_autocompletor_find(TideAutoCompleter completer, const char* hint)
{
    auto autoCompleter = static_cast<TidePluginAutoCompleter*>(completer);
    auto result = autoCompleter->find(std::string(hint));
    return static_cast<TideAutoCompleterResult>(result);
}

TideAutoCompleterResult tide_plugin_autocompletor_next(TideAutoCompleterResult result)
{
    if (!result)
        return nullptr;

    const auto res = static_cast<TidePluginAutoCompleterResult*>(result)->next;
    return static_cast<TideAutoCompleterResult>(res);
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