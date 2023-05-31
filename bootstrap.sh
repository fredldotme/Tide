#!/bin/bash

set -e

# 1) LLVM
OLD_PWD=$(pwd)
cd 3rdparty/llvm/
./bootstrap.sh
cd $OLD_PWD

# 2) wasi-sdk
OLD_PWD=$(pwd)
if [ ! -d tmp ]; then
    mkdir tmp
fi
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/wasi-sysroot-20.0.tar.gz --output wasi-sdk.tar.gz
tar xvf wasi-sdk.tar.gz
cd $OLD_PWD

# 3) libclang_rt
OLD_PWD=$(pwd)
if [ ! -d tmp ]; then
    mkdir tmp
fi
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/libclang_rt.builtins-wasm32-wasi-20.0.tar.gz --output clangrt.tar.gz
tar xvf clangrt.tar.gz
cd $OLD_PWD

# Done!
exit 0
