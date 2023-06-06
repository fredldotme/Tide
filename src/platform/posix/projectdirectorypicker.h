#ifndef PROJECTDIRECTORYPICKER_H
#define PROJECTDIRECTORYPICKER_H

#include <QObject>

class ProjectDirectoryPicker : public QObject
{
    Q_OBJECT
public:
    explicit ProjectDirectoryPicker(QObject *parent = nullptr);

signals:

};

#endif // PROJECTDIRECTORYPICKER_H
