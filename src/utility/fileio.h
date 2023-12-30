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
    void createDirectory(const QString path);
    void createFile(const QString path);
    void deleteFileOrDirectory(const QString path);
    qint64 fileSize(const QString path);
    quint64 directoryContents(const QString path);
    bool fileIsTextFile(const QString path);

signals:
    void directoryCreated(const QString path, const QString parent);
    void fileCreated(const QString path, const QString parent);
    void pathDeleted(const QString path);
};

#endif // FILEIO_H
