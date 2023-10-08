#ifndef WASMRUNNER_H
#define WASMRUNNER_H

#include "common/wasmrunnerinterface.h"
#include "utility/wasmrunner.h"

struct WasmRuntimePrivate {
    WasmRunnerInterface* interface;
};

#endif
