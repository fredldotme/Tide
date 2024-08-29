#ifndef PROGRAMSPEC_H
#define PROGRAMSPEC_H

#include <QObject>

class StdioSpec {
    Q_GADGET

public:
    FILE* std_in = nullptr;
    FILE* std_out = nullptr;
    FILE* std_err = nullptr;
};
Q_DECLARE_METATYPE(StdioSpec)

class SystemGlueProcess {
    Q_GADGET

public:
    quint64 pid = 0;
    StdioSpec stdio;
    int exitCode = 0;
};
Q_DECLARE_METATYPE(SystemGlueProcess)

#endif // PROGRAMSPEC_H
