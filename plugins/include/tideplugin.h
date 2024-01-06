#ifndef TIDEPLUGININTERFACE_H
#define TIDEPLUGININTERFACE_H

enum TidePluginFeatures {
    NoneFeature = 0,
    IDEProject = (1 << 1),
    IDEConsole = (1 << 2),
    IDEContextMenu = (1 << 3),
    IDEDebugger = (1 << 4),
    IDEAutoComplete = (1 << 5),
};

#define PUBLIC __attribute__((visibility("default")))

TidePluginFeatures PUBLIC tide_plugin_features();
const char* PUBLIC tide_plugin_name();
const char* PUBLIC tide_plugin_description();

#endif