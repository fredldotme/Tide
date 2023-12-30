import QtQml

QtObject {
    readonly property bool supportsAot : Qt.platform.os === "osx" || Qt.platform.os === "linux"
}
