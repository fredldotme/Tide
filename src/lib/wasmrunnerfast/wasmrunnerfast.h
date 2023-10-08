#ifndef WASMRUNNER_H
#define WASMRUNNER_H

#include "common/wasmrunnerinterface.h"

struct WasmRuntimePrivate {
    WasmRunnerInterface* interface;
};

#endif
