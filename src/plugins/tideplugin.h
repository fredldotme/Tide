#ifndef TIDEPLUGIN_H
#define TIDEPLUGIN_H

#include <QObject>
#include <QSharedPointer>

#include "wasmloadable.h"

struct TidePluginCache {
    QString name;
    QString description;
    WasmLoadable::WasmLoaderFeature feature;
};

class TidePlugin
{
    Q_GADGET

    Q_PROPERTY(QString path MEMBER m_path CONSTANT)
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString description READ description CONSTANT)

public:
    TidePlugin(const QString& path);
    TidePlugin(const TidePlugin& o);
    ~TidePlugin();
    WasmLoadableInterface interface(const WasmLoadable::WasmLoaderFeature feature);

    const QString name();
    const QString description();
    const WasmLoadable::WasmLoaderFeature features();
    bool isValid() const;

    QSharedPointer<WasmLoadable> loadable();

private:
    QString m_path;
    QSharedPointer<WasmLoadable> m_loadable;
    TidePluginCache m_cache;
};
Q_DECLARE_METATYPE(TidePlugin)

#endif // TIDEPLUGIN_H
