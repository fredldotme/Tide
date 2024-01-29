#ifndef POSIXINTEGRATIONDELEGATE_H
#define POSIXINTEGRATIONDELEGATE_H

#include <QObject>
#include <QTimer>

#include <libudev.h>

class PosixIntegrationDelegate : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool hasKeyboard MEMBER hasKeyboard NOTIFY hasKeyboardChanged);

public:
    explicit PosixIntegrationDelegate(QObject *parent = nullptr);
    ~PosixIntegrationDelegate();
private:
    bool hasKeyboard;
    struct udev* m_udev;
    QTimer m_kbTimer;

signals:
    void hasKeyboardChanged();

};

#endif // POSIXINTEGRATIONDELEGATE_H
