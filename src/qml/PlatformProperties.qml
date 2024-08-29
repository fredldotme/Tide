import QtQml

QtObject {
    readonly property bool supportsOptimizations : Qt.platform.os === "osx" || Qt.platform.os === "linux"
    readonly property bool supportsCMake : Qt.platform.os === "linux" || Qt.platform.os === "osx"
    readonly property bool supportsSnaps : Qt.platform.os === "linux"
    readonly property bool supportsClickable : Qt.platform.os === "linux"
    readonly property bool supportsEmbeddedStatusbar : Qt.platform.os === "ios"
    readonly property bool usesHudBusyIndicator : Qt.platform.os === "ios" || Qt.platform.os === "osx"
    readonly property bool usesBuiltinOsk: Qt.platform.os === "linux" && useQtVirtualKeyboard // Set in main.cpp
    readonly property bool usesUiDelegateForOskHeight: Qt.platform.os === "ios"
    readonly property bool usesQtForOskHeight: Qt.platform.os === "linux"
    readonly property bool hasShell: Qt.platform.os === "linux" || Qt.platform.os === "osx"
}
