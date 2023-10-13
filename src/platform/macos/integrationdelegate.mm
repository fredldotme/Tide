#include "integrationdelegate.h"

#include <QDebug>
#include <QGuiApplication>
#include <QtGui/qpa/qplatformnativeinterface.h>
#include <QRect>
#include <QQuickWindow>
#include <QWindow>

MacosIntegrationDelegate::MacosIntegrationDelegate(QObject *parent)
    : QObject{parent}, m_oskVisible{false}, m_oskHeight{0}, m_item{nullptr}
{
}

void MacosIntegrationDelegate::setOskRect(const int width, const int height)
{
}

void MacosIntegrationDelegate::setOskVisible(const bool val)
{
}

void MacosIntegrationDelegate::setItem(QQuickItem* item)
{
    if (this->m_item == item)
        return;

    this->m_item = item;
    emit itemChanged();
}

void MacosIntegrationDelegate::hookUpNativeView(QQuickItem* item)
{
}

QQuickItem* MacosIntegrationDelegate::item()
{
    return this->m_item;
}
