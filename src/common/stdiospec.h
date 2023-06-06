#ifndef PROGRAMSPEC_H
#define PROGRAMSPEC_H

#include <QObject>

class StdioSpec {
    Q_GADGET

public:
    FILE* stdin = nullptr;
    FILE* stdout = nullptr;
    FILE* stderr = nullptr;
};

Q_DECLARE_METATYPE(StdioSpec)

#endif // PROGRAMSPEC_H
