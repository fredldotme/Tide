#ifndef TIDEPLUGININTERFACE_H
#define TIDEPLUGININTERFACE_H

#ifdef __cplusplus
extern "C"{
#endif

enum TidePluginFeatures {
    NoneFeature = 0,
    IDEProject = (1 << 1),
    IDEConsole = (1 << 2),
    IDEContextMenu = (1 << 3),
    IDEDebugger = (1 << 4),
    IDEAutoComplete = (1 << 5),
};

// Specializations
typedef void* TidePluginInterface;
typedef void* TideAutoCompleterResult;
typedef void* TideAutoCompleter;

// Plugins define publicly available functions
#define PUBLIC __attribute__((visibility("default")))

// Main entry points
TidePluginFeatures PUBLIC tide_plugin_features();
const char* PUBLIC tide_plugin_name();
const char* PUBLIC tide_plugin_description();
TidePluginInterface PUBLIC tide_plugin_get_interface(const TidePluginFeatures feature);

// AutoCompleter interface
TideAutoCompleterResult PUBLIC tide_plugin_autocompletor_find(TideAutoCompleter completer,
                                                              const char* hint);
TideAutoCompleterResult PUBLIC tide_plugin_autocompletor_next(TideAutoCompleterResult result);
void PUBLIC tide_plugin_autocompletorresult_destroy(TideAutoCompleterResult result);
const char* PUBLIC tide_plugin_autocompletorresult_type(TideAutoCompleterResult result);
const char* PUBLIC tide_plugin_autocompletorresult_identifier(TideAutoCompleterResult result);

#ifdef __cplusplus
}
#endif
#endif