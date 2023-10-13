#include "imeventfixer.h"

#include <QInputMethodQueryEvent>

ImEventFixer::ImEventFixer(QObject *parent) : QObject(parent)
{

}

bool ImEventFixer::eventFilter(QObject *obj, QEvent *event)
{
    return QObject::eventFilter(obj, event);
}
