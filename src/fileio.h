#ifndef FILEIO_H
#define FILEIO_H

#include <QObject>

class FileIo : public QObject
{
    Q_OBJECT
public:
    explicit FileIo(QObject *parent = nullptr);

public slots:
    QString readFile(const QString path);
    bool writeFile(const QString path, const QByteArray content);
};

#endif // FILEIO_H
