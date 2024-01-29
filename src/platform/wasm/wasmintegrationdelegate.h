#ifndef POSIXINTEGRATIONDELEGATE_H
#define POSIXINTEGRATIONDELEGATE_H

#include <QObject>

class PosixIntegrationDelegate : public QObject
{
    Q_OBJECT
public:
    explicit PosixIntegrationDelegate(QObject *parent = nullptr);

signals:

};

#endif // POSIXINTEGRATIONDELEGATE_H
