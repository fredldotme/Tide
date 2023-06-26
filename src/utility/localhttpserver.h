#ifndef LOCALHTTPSERVER_H
#define LOCALHTTPSERVER_H

#include <QObject>

class LocalHttpServer : public QObject
{
    Q_OBJECT
public:
    explicit LocalHttpServer(QObject *parent = nullptr);

signals:

};

#endif // LOCALHTTPSERVER_H
