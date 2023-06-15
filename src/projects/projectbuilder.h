#ifndef PROJECTBUILDER_H
#define PROJECTBUILDER_H

#include <QObject>
#include <QString>

#include <qmakeparser.h>

#include "platform/systemglue.h"

class ProjectBuilder : public QObject
{
    Q_OBJECT

    Q_PROPERTY(SystemGlue* commandRunner MEMBER m_iosSystem NOTIFY commandRunnerChanged)
    Q_PROPERTY(bool building MEMBER m_building NOTIFY buildingChanged)
    Q_PROPERTY(QString projectFile MEMBER m_projectFile NOTIFY projectFileChanged)

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
    QString buildRoot();
    QString sourceRoot();

private:
    QString projectBuildRoot();

    SystemGlue* m_iosSystem;
    QString m_sysroot;
    QString m_projectFile;
    bool m_building;

signals:
    void projectFileChanged();
    void commandRunnerChanged();
    void buildingChanged();
    void buildSuccess();
    void buildError(QString str);
};

#endif // PROJECTBUILDER_H
