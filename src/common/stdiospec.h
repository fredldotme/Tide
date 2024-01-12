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

#endif // PROGRAMSPEC_H
