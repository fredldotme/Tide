#ifndef PLUGININTERFACE_H
#define PLUGININTERFACE_H

#include <QObject>

class PluginInterface : public QObject
{
    Q_OBJECT
public:
    explicit PluginInterface(uint32_t interface, QObject *parent = nullptr);

signals:
};

#endif // PLUGININTERFACE_H
