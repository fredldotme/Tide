#ifndef TIDEPLUGINMANAGER_H
#define TIDEPLUGINMANAGER_H

#include <QObject>

#include "plugins/tideplugin.h"

class TidePluginManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList plugins READ plugins NOTIFY pluginsChanged FINAL)

public:
    explicit TidePluginManager(QObject *parent = nullptr);
    ~TidePluginManager();

    const QList<QSharedPointer<TidePlugin>>& pluginRefs();

public slots:
    void reloadPlugins();

private:
    QVariantList plugins();

    QList<QSharedPointer<TidePlugin>> m_plugins;

signals:
    void pluginsChanged();
};
Q_DECLARE_METATYPE(TidePluginManager)

#endif // TIDEPLUGINMANAGER_H
