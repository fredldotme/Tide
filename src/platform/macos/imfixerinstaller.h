#ifndef IMFIXERINSTALLER_H
#define IMFIXERINSTALLER_H

#include <QObject>
#include <QQuickItem>

#include "imeventfixer.h"

class ImFixerInstaller : public QObject
{
    Q_OBJECT
public:
    explicit ImFixerInstaller(QObject *parent = nullptr);
    Q_INVOKABLE void setupImEventFilter(QQuickItem *item);

};

#endif // IMFIXERINSTALLER_H
