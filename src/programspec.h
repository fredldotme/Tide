#ifndef PROGRAMSPEC_H
#define PROGRAMSPEC_H

#include <QObject>

class ProgramSpec {
    Q_GADGET

public:
    FILE* stdin;
    FILE* stdout;
    FILE* stderr;
};

Q_DECLARE_METATYPE(ProgramSpec)

#endif // PROGRAMSPEC_H
