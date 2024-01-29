#include "posixintegrationdelegate.h"

#include <libudev.h>

#include <QDebug>

PosixIntegrationDelegate::PosixIntegrationDelegate(QObject *parent)
    : QObject{parent}, hasKeyboard{true}, m_udev{udev_new()}
{
    QObject::connect(&m_kbTimer, &QTimer::timeout, this, [=](){
        bool hasKb = false;
        struct udev_list_entry *devices, *dev_list_entry;
        struct udev_device *dev;
        struct udev_enumerate *enumerate = udev_enumerate_new(m_udev);

        udev_enumerate_add_match_property(enumerate, "ID_INPUT_KEYBOARD", "1");
        udev_enumerate_scan_devices(enumerate);
        devices = udev_enumerate_get_list_entry(enumerate);
        udev_list_entry_foreach(dev_list_entry, devices) {
            const char *path, *devnode;
            path = udev_list_entry_get_name(dev_list_entry);
            dev = udev_device_new_from_syspath(m_udev, path);
            devnode = udev_device_get_devnode(dev);
            if (devnode) {
                hasKb = true;
            }
            udev_device_unref(dev);
            if (hasKb)
                break;
        }
        udev_enumerate_unref(enumerate);

        if (hasKeyboard != hasKb) {
            hasKeyboard = hasKb;
            emit hasKeyboardChanged();
        }
    });

    m_kbTimer.setInterval(1000);
    m_kbTimer.setSingleShot(false);
    m_kbTimer.start();
}

PosixIntegrationDelegate::~PosixIntegrationDelegate()
{
    if (m_udev)
        udev_unref(m_udev);
    m_udev = nullptr;
}
