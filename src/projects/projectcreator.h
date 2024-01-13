#ifndef PROJECTCREATOR_H
#define PROJECTCREATOR_H

#include <QObject>

class ProjectCreator : public QObject
{
    Q_OBJECT

public:
    enum ProjectType {
        Application = 0,
        Library,
        TidePlugin
    };
    Q_ENUM(ProjectType)

    explicit ProjectCreator(QObject *parent = nullptr);

public slots:
    bool projectExists(const QString targetName);
    void createProject(const QString targetName, const ProjectType projectType);

signals:
    void projectCreated();

};

#endif // PROJECTCREATOR_H
