import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TideDialog {
    x: (parent.width - width) / 2
    y: ((parent.height - height) / 2)
    clip: true

    signal done()

    readonly property bool paneHeight : implicitHeight

    function show() {
        open()
    }

    function hide() {
        close()
        done()
    }

    Behavior on y {
        NumberAnimation {
            duration: dialogShadow.consoleAnimation
            easing.type: Easing.OutCubic
        }
    }
}

