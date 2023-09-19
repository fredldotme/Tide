#ifndef BUILDERBACKEND_H
#define BUILDERBACKEND_H

#include <QString>

class BuilderBackend {
public:
    virtual void setSysroot(const QString path) = 0;
    virtual bool loadProject(const QString path) = 0;
    virtual void unloadProject() = 0;

    virtual void clean() = 0;
    virtual void build(const bool debug, const bool aot) = 0;
    virtual void cancel() = 0;
    virtual QString runnableFile() = 0;
    virtual QStringList includePaths() = 0;
    virtual QString buildRoot() = 0;
    virtual QString sourceRoot() = 0;
    virtual QString projectBuildRoot() = 0;
    virtual bool building() = 0;
};

#endif // BUILDERBACKEND_H
