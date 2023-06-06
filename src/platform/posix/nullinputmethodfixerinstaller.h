#ifndef NULLINPUTMETHODFIXERINSTALLER_H
#define NULLINPUTMETHODFIXERINSTALLER_H

#include <QObject>

class NullInputMethodFixerInstaller : public QObject
{
    Q_OBJECT
public:
    explicit NullInputMethodFixerInstaller(QObject *parent = nullptr);

signals:

};

#endif // NULLINPUTMETHODFIXERINSTALLER_H
