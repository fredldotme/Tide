#ifndef PROJECTBUILDER_H
#define PROJECTBUILDER_H

#include <QObject>

#include <qmakeparser.h>

#include "iossystemglue.h"

class ProjectBuilder : public QObject
{
    Q_OBJECT

    Q_PROPERTY(IosSystemGlue* commandRunner MEMBER m_iosSystem NOTIFY commandRunnerChanged)
public:
    explicit ProjectBuilder(QObject *parent = nullptr);

public slots:
    void setSysroot(const QString path);
    bool loadProject(const QString path);
    void clean();
    void build();
    void cancel();
    QString runnableFile();

private:
    QString buildRoot();
    QString hash();

    IosSystemGlue* m_iosSystem;
    QString m_sysroot;
    QString m_projectFile;

signals:
    void commandRunnerChanged();
    void buildSuccess();
    void buildError(QString str);
};

#endif // PROJECTBUILDER_H
