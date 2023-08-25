#!/bin/bash

set -e

# Preparations
if [ ! -d tmp ]; then
    mkdir tmp
fi

IOS_SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
OLD_PWD=$(pwd)

function cmake_iossystem_build {
    echo "Custom args: $1"
    LIBNAME="$2"
    DYLIBNAME="$3"

    if [ -d build ]; then
        rm -rf build
    fi
    mkdir build
    cd build
    cmake \
        -G Ninja \
        -DCMAKE_OSX_SYSROOT=${IOS_SDKROOT} \
        -DCMAKE_C_COMPILER=$(xcrun --sdk iphoneos -f clang) \
        -DCMAKE_CXX_COMPILER=$(xcrun --sdk iphoneos -f clang++) \
        $1 ..
    ninja

    LIBFILE=$(find . -name ${DYLIBNAME})
    mkdir -p $OLD_PWD/tmp/$LIBNAME.framework
    cp -a $OLD_PWD/aux/$LIBNAME/Info.plist $OLD_PWD/tmp/$LIBNAME.framework/Info.plist
    cp -a $LIBFILE $OLD_PWD/tmp/$LIBNAME.framework/$LIBNAME
    plutil -convert binary1 $OLD_PWD/tmp/$LIBNAME.framework/Info.plist

    cd ..
}

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
        "$1" ..
    ninja
    cd ..
}

# LLVM
cd 3rdparty/llvm/
./bootstrap.sh
cd $OLD_PWD

# libclang
LIBNAME=libclang
cd tmp
rm -rf libclang.framework || true
mkdir -p $LIBNAME.framework
cd $LIBNAME.framework
cp -a $OLD_PWD/aux/libclang/Info.plist ./
cp -a $OLD_PWD/3rdparty/llvm/build-iphoneos/lib/libclang.dylib ./$LIBNAME
install_name_tool -change "@rpath/libLLVM.dylib" "@rpath/libLLVM.framework/libLLVM" ./$LIBNAME
install_name_tool -id "@rpath/libclang.framework/libclang" ./$LIBNAME
plutil -convert binary1 Info.plist
cd $OLD_PWD

# wasi-sdk
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/wasi-sysroot-20.0.tar.gz --output wasi-sdk.tar.gz
tar xvf wasi-sdk.tar.gz
cd $OLD_PWD

# libclang_rt
# ATTENTION: This meddles with the build result of the LLVM build on the macOS side
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/libclang_rt.builtins-wasm32-wasi-20.0.tar.gz --output clangrt.tar.gz
tar xvf clangrt.tar.gz
cp -a $OLD_PWD/tmp/lib/wasi $OLD_PWD/3rdparty/llvm/build_osx/lib/clang/14.0.0/lib/
cd $OLD_PWD

# Posix/Berkely socket support
cd aux/lib-socket
cmake_wasi_build
cp $OLD_PWD/aux/lib-socket/build/libsocket_wasi_ext.a $OLD_PWD/tmp/wasi-sysroot/lib/wasm32-wasi-threads/
cp $OLD_PWD/3rdparty/wamr/core/iwasm/libraries/lib-socket/inc/wasi_socket_ext.h $OLD_PWD/tmp/wasi-sysroot/include/
cd $OLD_PWD

# Package up the sysroot
if [ -d tmp/the-sysroot ]; then
    rm -rf tmp/the-sysroot
fi
mkdir -p tmp/the-sysroot/Clang
mkdir -p tmp/the-sysroot/Sysroot
mkdir -p tmp/the-sysroot/Clang/lib/wasi/
cp -a $OLD_PWD/tmp/wasi-sysroot/* tmp/the-sysroot/Sysroot
cp -a $OLD_PWD/3rdparty/llvm/build-iphoneos/lib/clang/14.0.0/include tmp/the-sysroot/Clang/
cp -a $OLD_PWD/tmp/lib/wasi/* tmp/the-sysroot/Clang/lib/wasi/
tar cvf tmp/the-sysroot.tar -C tmp/the-sysroot .
cd $OLD_PWD

# Rust
#cd 3rdparty/rust
#./bootstrap.sh
#cd $OLD_PWD

# CMake
cd 3rdparty/CMake
LIBNAME="cmake"
cmake_iossystem_build "-DBUILD_TESTING=0 -DIOS_SYSTEM_FRAMEWORK=$OLD_PWD/3rdparty/llvm/build-iphoneos/build/Release-iphoneos" "$LIBNAME" "lib${LIBNAME}.dylib"
cp -a Modules $OLD_PWD/tmp/$LIBNAME.framework/
cd $OLD_PWD

# Ninja
cd 3rdparty/ninja
LIBNAME="ninja"
cmake_iossystem_build "-DBUILD_TESTING=0 -DNINJA_BUILD_FRAMEWORK=1 -DIOS_SYSTEM_FRAMEWORK=$OLD_PWD/3rdparty/llvm/build-iphoneos/build/Release-iphoneos" "$LIBNAME" "lib${LIBNAME}exe.dylib"
cd $OLD_PWD

# Done!
exit 0
