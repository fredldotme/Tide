#include "tidepluginmanager.h"

#include <QDirIterator>
#include <QStandardPaths>

#include <iostream>

#include <wasm_c_api.h>
#include <wasm_export.h>

TidePluginManager::TidePluginManager(QObject *parent)
    : QObject{parent}
{
    const QString pluginDir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + "/Plugins";
    QDir plugin(pluginDir);
    if (!plugin.exists()) {
        plugin.mkpath(pluginDir);
    }

    static char global_heap_buf[32 * 1024 * 1024];

    /* all the runtime memory allocations are retricted in the global_heap_buf array */
    RuntimeInitArgs init_args;
    memset(&init_args, 0, sizeof(RuntimeInitArgs));

    /* configure the memory allocator for the runtime */
    init_args.mem_alloc_type = Alloc_With_Pool;
    init_args.mem_alloc_option.pool.heap_buf = global_heap_buf;
    init_args.mem_alloc_option.pool.heap_size = sizeof(global_heap_buf);

#if 0
    /* configure the native functions being exported to WASM app */
    init_args.native_module_name = "env";
    init_args.n_native_symbols = sizeof(native_symbols) / sizeof(NativeSymbol);
    init_args.native_symbols = native_symbols;
#endif

    /* set maximum thread number if needed when multi-thread is enabled, the default value is 4 */
    init_args.max_thread_num = 8;

    /* initialize runtime environment with user configurations*/
    if (!wasm_runtime_full_init(&init_args)) {
        return;
    }

    reloadPlugins();
}

TidePluginManager::~TidePluginManager()
{
    m_plugins.clear();
    wasm_runtime_destroy();
}

void TidePluginManager::reloadPlugins()
{
    const QString pluginDir = pluginsPath();
    QDirIterator dit(pluginDir, QDir::NoDotAndDotDot | QDir::AllEntries, QDirIterator::Subdirectories);

    m_plugins.clear();

    {
        QList<QSharedPointer<TidePlugin>> plugins;
        while(dit.hasNext()) {
            const auto next = dit.next();
            if (!next.endsWith(".a"))
                continue;

            auto plugin = QSharedPointer<TidePlugin>(new TidePlugin(next));
            if (!plugin->isValid())
                continue;

            std::cout << "Plugin name: " << plugin->name().toStdString() << std::endl;
            std::cout << "Plugin description: " << plugin->description().toStdString() << std::endl;
            std::cout << "Plugin features: " << plugin->features() << std::endl;

            plugins.push_back(plugin);
        }

        m_plugins = plugins;
    }

    emit pluginsChanged();
}

QVariantList TidePluginManager::plugins()
{
    QVariantList ret;
    for (const auto& plugin : m_plugins) {
        auto var = QVariant::fromValue<TidePlugin>(*plugin.get());
        ret << var;
    }
    return ret;
}

const QList<QSharedPointer<TidePlugin>>& TidePluginManager::pluginRefs()
{
    return m_plugins;
}

QString TidePluginManager::pluginsPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + "/Plugins";
}
