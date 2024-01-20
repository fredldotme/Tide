import QtQml

QtObject {
    readonly property bool supportsOptimizations : Qt.platform.os === "osx"
    readonly property bool supportsCMake : Qt.platform.os === "linux" || Qt.platform.os === "osx"
    readonly property bool supportsEmbeddedStatusbar : Qt.platform.os === "ios"
    readonly property bool usesHudBusyIndicator : true
}
