#ifndef PROJECTCREATOR_H
#define PROJECTCREATOR_H

#include <QObject>

class ProjectCreator : public QObject
{
    Q_OBJECT
public:
    explicit ProjectCreator(QObject *parent = nullptr);

public slots:
    bool projectExists(const QString targetName);
    void createProject(const QString targetName);

signals:
    void projectCreated();

};

#endif // PROJECTCREATOR_H
