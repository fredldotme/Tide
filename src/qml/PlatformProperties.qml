import QtQml

QtObject {
    readonly property bool supportsOptimizations : Qt.platform.os === "osx" || Qt.platform.os === "linux"
}
