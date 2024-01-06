#include <tideplugin.h>

TidePluginFeatures tide_plugin_features()
{
    return TidePluginFeatures::NoneFeature;
}

const char* tide_plugin_name()
{
    return "ExamplePlugin";
}

const char* tide_plugin_description()
{
    return "Showcasing plugin integration into Tide";
}