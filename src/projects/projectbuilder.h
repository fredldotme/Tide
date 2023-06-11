#ifndef PROJECTBUILDER_H
#define PROJECTBUILDER_H

#include <QObject>

#include <qmakeparser.h>

#include "platform/systemglue.h"

class ProjectBuilder : public QObject
{
    Q_OBJECT

    Q_PROPERTY(SystemGlue* commandRunner MEMBER m_iosSystem NOTIFY commandRunnerChanged)
    Q_PROPERTY(bool building MEMBER m_building NOTIFY buildingChanged)

public:
    explicit ProjectBuilder(QObject *parent = nullptr);

public slots:
    void setSysroot(const QString path);
    bool loadProject(const QString path);
    void clean();
    void build();
    void cancel();
    QString runnableFile();
    QStringList includePaths();

private:
    QString buildRoot();
    QString projectBuildRoot();

    SystemGlue* m_iosSystem;
    QString m_sysroot;
    QString m_projectFile;
    bool m_building;

signals:
    void commandRunnerChanged();
    void buildingChanged();
    void buildSuccess();
    void buildError(QString str);
};

#endif // PROJECTBUILDER_H
