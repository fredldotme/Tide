import QtQuick
import QtQuick.Controls

ToolButton {
    scale: pressed ? 0.9 : 1.0
    opacity: pressed || !enabled ? 0.5 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: 1000
            easing.type: Easing.OutQuad
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 750
            easing.type: Easing.OutQuad
        }
    }
}
