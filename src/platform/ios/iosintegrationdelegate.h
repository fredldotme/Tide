#ifndef IOSINTEGRATIONDELEGATE_H
#define IOSINTEGRATIONDELEGATE_H

#include <QObject>
#include <QQuickItem>

class IosIntegrationDelegate : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool oskVisible MEMBER m_oskVisible NOTIFY oskVisibleChanged)
    Q_PROPERTY(int oskHeight MEMBER m_oskHeight NOTIFY oskHeightChanged)
    Q_PROPERTY(QQuickItem* item MEMBER m_item NOTIFY itemChanged)
    Q_PROPERTY(int statusBarHeight MEMBER m_statusBarHeight CONSTANT);

public:
    explicit IosIntegrationDelegate(QObject *parent = nullptr);

    void setOskRect(const int width, const int height);
    void setOskVisible(const bool val);

private:
    bool m_oskVisible;
    int m_oskWidth;
    int m_oskHeight;
    int m_statusBarHeight;
    QQuickItem* m_item;

signals:
    void oskVisibleChanged();
    void oskWidthChanged();
    void oskHeightChanged();
    void statusBarHeightChanged();
    void itemChanged();
};

#endif // IOSINTEGRATIONDELEGATE_H
