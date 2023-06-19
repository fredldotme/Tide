#ifndef QMAKEBUILDER_H
#define QMAKEBUILDER_H

#include <QObject>
#include <QString>

#include <qmakeparser.h>

#include "builderbackend.h"
#include "platform/systemglue.h"

class QMakeBuilder : public QObject, public BuilderBackend
{
    Q_OBJECT

    Q_PROPERTY(SystemGlue* commandRunner MEMBER iosSystem NOTIFY commandRunnerChanged)
    Q_PROPERTY(bool building READ building NOTIFY buildingChanged)
    Q_PROPERTY(QString projectFile MEMBER m_projectFile NOTIFY projectFileChanged)

public:
    explicit QMakeBuilder(QObject *parent = nullptr);
    SystemGlue* iosSystem;

public slots:
    void setSysroot(const QString path) override;
    bool loadProject(const QString path) override;
    void clean() override;
    void build() override;
    void cancel() override;
    QString runnableFile() override;
    QStringList includePaths() override;
    QString buildRoot() override;
    QString sourceRoot() override;
    QString projectBuildRoot() override;
    bool building() override;

private:
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

#endif // QMAKEBUILDER_H
