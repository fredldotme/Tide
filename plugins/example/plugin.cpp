#include <tideplugin.h>

#include <string>
#include <iostream>
#include <vector>

extern "C" {

class TidePluginHostInterface {};

struct TidePluginAutoCompleterResult {
    AutoCompletorKind kind;
    std::string type;
    std::string identifier;
    std::string detail;
};

class TidePluginAutoCompleter : public TidePluginHostInterface {
public:
    bool setup(const std::string& contents);
    TidePluginAutoCompleterResult* find(const std::string& hint);
    TidePluginAutoCompleterResult* next();
private:
    std::vector<TidePluginAutoCompleterResult> completionResults;
    std::vector<TidePluginAutoCompleterResult>::iterator cit;
};

static TidePluginAutoCompleter globalAutoCompleter;

bool TidePluginAutoCompleter::setup(const std::string& contents)
{
    completionResults.clear();
    for (int i = 0; i < 3; i++) {
        TidePluginAutoCompleterResult res;
        res.kind = AutoCompletorKind::Variable;
        res.type = "int";
        res.identifier = "PluginWorking_" + std::to_string(i);
        res.detail = "ExamplePlugin";
        completionResults.push_back(res);
    }
    cit = completionResults.begin();
    return true;
}

TidePluginAutoCompleterResult* TidePluginAutoCompleter::find(const std::string& hint)
{
    return &(*cit);
}

TidePluginAutoCompleterResult* TidePluginAutoCompleter::next()
{
    auto it = (cit + 1);
    if (it == completionResults.end())
        return nullptr;
    cit = it;
    return &(*it);
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

TideAutoCompleterResult tide_plugin_autocompletor_next(TideAutoCompleter completer)
{
    if (!completer)
        return nullptr;

    const auto comp = static_cast<TidePluginAutoCompleter*>(completer);
    return static_cast<TideAutoCompleterResult>(comp->next());
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
