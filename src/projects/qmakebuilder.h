#ifndef QMAKEBUILDER_H
#define QMAKEBUILDER_H

#include <QObject>
#include <QString>

#include <qmakeparser.h>

#include "builderbackend.h"
#include "platform/systemglue.h"

class QMakeBuilder : public BuilderBackend
{
    Q_OBJECT

    Q_PROPERTY(SystemGlue* commandRunner MEMBER iosSystem NOTIFY commandRunnerChanged)
    Q_PROPERTY(bool building READ building NOTIFY buildingChanged)
    Q_PROPERTY(QString projectFile MEMBER m_projectFile NOTIFY projectFileChanged)
    Q_PROPERTY(bool runnable READ isRunnable NOTIFY runnableChanged)

public:
    explicit QMakeBuilder(QObject *parent = nullptr);
    SystemGlue* iosSystem;

public slots:
    void setSysroot(const QString path) override;
    bool loadProject(const QString path) override;
    void unloadProject() override;
    void clean() override;
    void build(const bool debug, const bool aot) override;
    void cancel() override;
    QString runnableFile() override;
    QStringList includePaths() override;
    QString buildRoot() override;
    QString sourceRoot() override;
    QString projectBuildRoot() override;
    QStringList sourceFiles() override;
    bool building() override;
    bool isRunnable() override;

private:
    QString m_sysroot;
    QString m_projectFile;
    bool m_building;

signals:
    void commandRunnerChanged();
};

#endif // QMAKEBUILDER_H
