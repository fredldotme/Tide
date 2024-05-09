# Tide - The touch-friendly IDE

Welcome to Tide, your new favorite IDE for touch devices!

![Preview](PREVIEW.png)


## Overview

Tide IDE is a WebAssembly development environment for all kinds of form factors, but mainly for touch-enabled computing devices. It features:

- A simple yet functional Qt/QML-based user interface
- Integrated compiler toolchain with recent C & C++ support 
- Debugger with breakpoints & single-stepping
- Various libraries included
- Autocomplete with search
- Autoformat
- Console with stdout/stderr filtering
- Import projects from external applications
- Project-wide Search and Replace
- Release your WebAssembly apps to the world
- Integrated Rubber Duck Debugging


## Under the hood

This project uses LLVM + Clang and the Wasi SDK to provide a compiler toolchain for C & C++ projects. For the WebAssembly runtime it uses WAMR.

## Building Tide

### iPadOS

Building Tide requires a recent Xcode and QtCreator and prerequisite components built:

```
./bootstrap.sh
```

Afterwards you can open the CMake project in QtCreator.


## Supporting Tide

Tide IDE is Free and Open Source Software, but support is necessary to keep the project afloat. Instead of jumping through hoops of building the software yourself you can purchase Tide IDE from the App Store.

- [Apple App Store](https://apps.apple.com/at/app/tide-ide/id6450320573)


## Privacy policy

Tide does not automatically send any data to anyone.


## License

Copyright Alfred Neumayer (C) 2023

This software is licensed under the MIT license.


## Further copyright notices

- `LLVM`: Apache 2.0 License with LLVM exceptions
- `WAMR`: Apache 2.0
- `Wasi SDK`: Apache 2.0
- `libqmakeparser`: BSD 3-Clause License
- `no_system`: BSD 3-Clause License
- `SF symbols`: Apple Inc.
- Tide icon by Parmjot Singh
