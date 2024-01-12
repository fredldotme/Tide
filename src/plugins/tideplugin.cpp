#include "tideplugin.h"

#include <QDebug>

TidePlugin::TidePlugin(const QString& path) :
    m_path{path},
    m_loadable{new WasmLoadable(path)}
{
}

TidePlugin::TidePlugin(const TidePlugin& o)
{
    m_path = o.m_path;
    m_cache = o.m_cache;
    m_loadable = o.m_loadable;
}

TidePlugin::~TidePlugin()
{
}

const QString TidePlugin::name()
{
    if (!m_cache.name.isEmpty()) {
        return m_cache.name;
    }
    const auto ret = m_loadable->name();
    m_cache.name = ret;
    return ret;
}

const QString TidePlugin::description()
{
    if (!m_cache.description.isEmpty()) {
        return m_cache.description;
    }
    const auto ret = m_loadable->description();
    m_cache.description = ret;
    return ret;
}

const WasmLoadable::WasmLoaderFeature TidePlugin::features()
{
    if (m_cache.feature != 0) {
        return m_cache.feature;
    }
    const auto ret = m_loadable->features();
    m_cache.feature = ret;
    return ret;
}

WasmLoadableInterface TidePlugin::interface(const WasmLoadable::WasmLoaderFeature feature)
{
    return m_loadable->interface(feature);
}

bool TidePlugin::isValid() const
{
    return m_loadable->isValid();
}

QSharedPointer<WasmLoadable> TidePlugin::loadable()
{
    return m_loadable;
}
