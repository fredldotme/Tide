#ifndef NULLINPUTMETHODFIXERINSTALLER_H
#define NULLINPUTMETHODFIXERINSTALLER_H

#include <QObject>
#include <QQuickItem>

class NullInputMethodFixerInstaller : public QObject
{
    Q_OBJECT
public:
    explicit NullInputMethodFixerInstaller(QObject *parent = nullptr);
    Q_INVOKABLE void setupImEventFilter(QQuickItem *item);
signals:

};

#endif // NULLINPUTMETHODFIXERINSTALLER_H
