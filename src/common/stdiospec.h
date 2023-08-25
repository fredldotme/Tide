#ifndef PROGRAMSPEC_H
#define PROGRAMSPEC_H

#include <QObject>

class StdioSpec {
    Q_GADGET

public:
    FILE* stdin = nullptr;
    int stdinfd = -1;
    FILE* stdout = nullptr;
    int stdoutfd = -1;
    FILE* stderr = nullptr;
    int stderrfd = -1;
};

Q_DECLARE_METATYPE(StdioSpec)

#endif // PROGRAMSPEC_H
