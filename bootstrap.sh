#!/bin/bash

set -e

# Preparations
if [ ! -d tmp ]; then
    mkdir tmp
fi

# 1) LLVM
OLD_PWD=$(pwd)
cd 3rdparty/llvm/
./bootstrap.sh
cd $OLD_PWD

# 2) libclang
OLD_PWD=$(pwd)
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
OLD_PWD=$(pwd)
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/wasi-sysroot-20.0.tar.gz --output wasi-sdk.tar.gz
tar xvf wasi-sdk.tar.gz
cd $OLD_PWD

# 4) libclang_rt
OLD_PWD=$(pwd)
cd tmp
curl -L https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/libclang_rt.builtins-wasm32-wasi-20.0.tar.gz --output clangrt.tar.gz
tar xvf clangrt.tar.gz
cd $OLD_PWD

# 5) LLVM Header inclusion
OLD_PWD=$(pwd)
cp -a $OLD_PWD/3rdparty/llvm/build-iphoneos/lib/clang/14.0.0/include $OLD_PWD/tmp/wasi-sysroot/
cd $OLD_PWD

# Done!
exit 0
