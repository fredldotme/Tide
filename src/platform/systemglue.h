#ifndef SYSTEMGLUE_H
#define SYSTEMGLUE_H

#include <QtGlobal>

#ifdef Q_OS_LINUX
#include "platform/posix/posixsystemglue.h"
#include "platform/posix/projectdirectorypicker.h"
#include "platform/posix/posixintegrationdelegate.h"
#include "platform/posix/nullinputmethodfixerinstaller.h"
#include "platform/posix/posixprojectlist.h"

typedef PosixSystemGlue SystemGlue;
typedef ProjectDirectoryPicker ProjectPicker;
typedef PosixIntegrationDelegate PlatformIntegrationDelegate;
typedef NullInputMethodFixerInstaller InputMethodFixerInstaller;
typedef PosixProjectList ProjectList;
#elif Q_OS_IOS
#include "platform/ios/iossystemglue.h"
#include "platform/ios/externalprojectpicker.h"
#include "platform/ios/iosintegrationdelegate.h"
#include "platform/ios/imfixerinstaller.h"
#include "platform/ios/projectlist.h"

typedef IosSystemGlue SystemGlue;
typedef ExternalProjectPicker ProjectPicker;
typedef IosIntegrationDelegate PlatformIntegrationDelegate;
typedef ImFixerInstaller InputMethodFixerInstaller;
typedef IosProjectList ProjectList;
#endif

#endif // SYSTEMGLUE_H
