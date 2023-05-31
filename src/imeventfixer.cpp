#include "imeventfixer.h"

#include <QInputMethodQueryEvent>

ImEventFixer::ImEventFixer(QObject *parent) : QObject(parent)
{

}

bool ImEventFixer::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::InputMethodQuery) {
        QInputMethodQueryEvent *imEvt = static_cast<QInputMethodQueryEvent *>(event);
        if (imEvt->queries() == Qt::InputMethodQuery::ImCursorRectangle) {
            imEvt->setValue(Qt::InputMethodQuery::ImCursorRectangle, QRectF());
            return true;
        }
    }
    return QObject::eventFilter(obj, event);
}
