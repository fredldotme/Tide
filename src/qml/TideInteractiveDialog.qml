import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsDialog
    x: (parent.width - width) / 2
    y: visibility ? ((parent.height - height) / 2) : parent.height
    opacity: visibility ? 1.0 : 0.0
    visible: true
    clip: true
    color: root.palette.base
    radius: root.roundedCornersRadius

    readonly property bool paneHeight : childrenRect.height

    property bool visibility : false

    function show() {
        dialogShadow.opacity = 0.3
        visibility = true
    }

    function hide() {
        dialogShadow.opacity = 0.0
        visibility = false
    }

    Behavior on y {
        NumberAnimation {
            duration: dialogShadow.consoleAnimation
            easing.type: Easing.OutCubic
        }
    }
}

