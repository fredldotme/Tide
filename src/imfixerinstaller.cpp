#include "imfixerinstaller.h"

ImFixerInstaller::ImFixerInstaller(QObject *parent) : QObject(parent)
{

}

void ImFixerInstaller::setupImEventFilter(QQuickItem *item)
{
    static ImEventFixer ief;
    item->installEventFilter(&ief);
}
