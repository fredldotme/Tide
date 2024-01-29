#include "nullinputmethodfixerinstaller.h"

NullInputMethodFixerInstaller::NullInputMethodFixerInstaller(QObject *parent)
    : QObject{parent}
{

}

void NullInputMethodFixerInstaller::setupImEventFilter(QQuickItem *item)
{
}
