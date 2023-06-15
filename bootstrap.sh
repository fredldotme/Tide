#!/bin/bash

set -e

# Preparations
if [ ! -d tmp ]; then
    mkdir tmp
fi

OLD_PWD=$(pwd)

function cmake_wasi_build {
    if [ -d build ]; then
        rm -rf build
    fi
    mkdir build
    cd build
    cmake \
        -G Ninja \
        -DCMAKE_SYSTEM_NAME=WASI \
        -DCMAKE_SYSTEM_VERSION=1 \
        -DCMAKE_SYSTEM_PROCESSOR=wasm32 \
        -DCMAKE_C_COMPILER=$OLD_PWD/3rdparty/llvm/build_osx/bin/clang \
        -DCMAKE_CXX_COMPILER=$OLD_PWD/3rdparty/llvm/build_osx/bin/clang++ \
        -DCMAKE_ASM_COMPILER=$OLD_PWD/3rdparty/llvm/build_osx/bin/clang \
        -DCMAKE_AR=$OLD_PWD/3rdparty/llvm/build_osx/bin/llvm-ar \
        -DCMAKE_RANLIB=$OLD_PWD/3rdparty/llvm/build_osx/bin/llvm-ranlib \
        -DCMAKE_C_COMPILER_TARGET=wasm32-wasi-threads \
        -DCMAKE_CXX_COMPILER_TARGET=wasm32-wasi-threads \
        -DCMAKE_ASM_COMPILER_TARGET=wasm32-wasi-threads \
        -DCMAKE_SYSROOT=$OLD_PWD/tmp/wasi-sysroot \
        -DCMAKE_C_FLAGS="-Wl,--shared-memory -pthread -ftls-model=local-exec -mbulk-memory" \
        -DCMAKE_CXX_FLAGS="-Wl,--shared-memory -pthread -ftls-model=local-exec -mbulk-memory" \
        "$1" \
    ..
    ninja
    cd ..
}

# 1) LLVM
cd 3rdparty/llvm/
./bootstrap.sh
cd $OLD_PWD

# 2) libclang
LIBNAME=libclang
cd tmp
rm -rf libclang.framework || true
mkdir -p $LIBNAME.framework
cd $LIBNAME.framework
cp -a $OLD_PWD/aux/libclang/Info.plist ./
cp -a $OLD_PWD/3rdparty/llvm/build-iphoneos/lib/libclang.dylib ./$LIBNAME
install_name_tool -change "@rpath/libLLVM.dylib" "@rpath/libLLVM.framework/libLLVM" ./$LIBNAME
plutil -convert binary1 Info.plist
cd $OLD_PWD

# 3) wasi-sdk
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/wasi-sysroot-20.0.tar.gz --output wasi-sdk.tar.gz
tar xvf wasi-sdk.tar.gz
cd $OLD_PWD

# 4) libclang_rt
# ATTENTION: This meddles with the build result of the LLVM build on the macOS side
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/libclang_rt.builtins-wasm32-wasi-20.0.tar.gz --output clangrt.tar.gz
tar xvf clangrt.tar.gz
cp -a $OLD_PWD/tmp/lib/wasi $OLD_PWD/3rdparty/llvm/build_osx/lib/clang/14.0.0/lib/
cd $OLD_PWD

# 5) Posix/Berkely socket support
cd aux/lib-socket
cmake_wasi_build
cp $OLD_PWD/aux/lib-socket/build/libsocket_wasi_ext.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
cp $OLD_PWD/3rdparty/wamr/core/iwasm/libraries/lib-socket/inc/wasi_socket_ext.h $OLD_PWD/tmp/wasi-sysroot/include/
cd $OLD_PWD

# 6) Rust
#cd 3rdparty/rust
#./bootstrap.sh
#cd $OLD_PWD

# Done!
exit 0
