#ifndef PROJECTBUILDER_H
#define PROJECTBUILDER_H

#include <QObject>
#include <QString>

#include <qmakeparser.h>

#include "projects/cmakebuilder.h"
#include "projects/qmakebuilder.h"
#include "projects/snapcraftbuilder.h"
#include "platform/systemglue.h"

class ProjectBuilder : public QObject
{
    Q_OBJECT

    Q_PROPERTY(SystemGlue* commandRunner MEMBER m_iosSystem NOTIFY commandRunnerChanged)
    Q_PROPERTY(QString projectFile MEMBER m_projectFile NOTIFY projectFileChanged)
    Q_PROPERTY(QStringList sourceFiles READ sourceFiles NOTIFY sourceFilesChanged)
    Q_PROPERTY(bool building READ building NOTIFY buildingChanged)

    // Refreshable properties
    Q_PROPERTY(bool runnable READ isRunnable NOTIFY runnableChanged)

public:
    explicit ProjectBuilder(QObject *parent = nullptr);

public slots:
    void setSysroot(const QString path);
    bool loadProject(const QString path);
    void unloadProject();

    void reloadProperties();

    void clean();
    void build(const bool debug, const bool aot);
    void cancel();

    QString runnableFile();
    QStringList includePaths();
    QString buildRoot();
    QString sourceRoot();

    bool building();
    bool isRunnable();

private:
    QString projectBuildRoot();
    QStringList sourceFiles();

    SystemGlue* m_iosSystem;
    QString m_sysroot;
    QString m_projectFile;
    bool m_building;
    CMakeBuilder m_cmakeBuilder;
    QMakeBuilder m_qmakeBuilder;
    SnapcraftBuilder m_snapcraftBuilder;
    BuilderBackend* m_activeBuilder;

signals:
    void projectFileChanged();
    void commandRunnerChanged();
    void buildingChanged();
    void buildSuccess(bool debug, bool aot);
    void buildError(QString str);
    void cleaned();
    void sourceFilesChanged();
    void runnableChanged();
    void refreshingProperties();
};

#endif // PROJECTBUILDER_H
