#ifndef SYSTEMGLUE_H
#define SYSTEMGLUE_H

#include <QtSystemDetection>

#if defined(Q_OS_LINUX)
#include <unistd.h>

#include "platform/posix/posixsystemglue.h"
#include "platform/posix/projectdirectorypicker.h"
#include "platform/posix/posixintegrationdelegate.h"
#include "platform/posix/nullinputmethodfixerinstaller.h"
#include "platform/posix/posixprojectlist.h"
#include "platform/posix/clangcompiler.h"

typedef PosixSystemGlue SystemGlue;
typedef ProjectDirectoryPicker ProjectPicker;
typedef PosixIntegrationDelegate PlatformIntegrationDelegate;
typedef NullInputMethodFixerInstaller InputMethodFixerInstaller;
typedef PosixProjectList ProjectList;
#elif defined(Q_OS_IOS)
#include "platform/ios/iossystemglue.h"
#include "platform/ios/externalprojectpicker.h"
#include "platform/ios/iosintegrationdelegate.h"
#include "platform/ios/imfixerinstaller.h"
#include "platform/ios/clangcompiler.h"
#include "platform/darwin/iosprojectlist.h"

typedef IosSystemGlue SystemGlue;
typedef ExternalProjectPicker ProjectPicker;
typedef IosIntegrationDelegate PlatformIntegrationDelegate;
typedef ImFixerInstaller InputMethodFixerInstaller;
typedef IosProjectList ProjectList;
#elif defined(Q_OS_MACOS)
#include <unistd.h>

#include "platform/macos/macsystemglue.h"
#include "platform/macos/externalprojectpicker.h"
#include "platform/macos/integrationdelegate.h"
#include "platform/macos/imfixerinstaller.h"
#include "platform/darwin/iosprojectlist.h"

typedef MacSystemGlue SystemGlue;
typedef ExternalProjectPicker ProjectPicker;
typedef MacosIntegrationDelegate PlatformIntegrationDelegate;
typedef ImFixerInstaller InputMethodFixerInstaller;
typedef IosProjectList ProjectList;
#endif

#endif // SYSTEMGLUE_H
