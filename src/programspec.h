#ifndef PROGRAMSPEC_H
#define PROGRAMSPEC_H

#include <QObject>

class ProgramSpec {
    Q_GADGET

public:
    FILE* stdin = nullptr;
    FILE* stdout = nullptr;
    FILE* stderr = nullptr;
};

Q_DECLARE_METATYPE(ProgramSpec)

#endif // PROGRAMSPEC_H
