import QtQuick
import QtQuick.Controls

Button {
    scale: pressed ? 0.9 : 1.0
    opacity: pressed || !enabled ? 0.5 : 1.0
    flat: true
    icon.width: menuItemIconSize
    icon.height: menuItemIconSize
    spacing: text !== "" ? paddingSmall : 0
    padding: 0
    horizontalPadding: 0

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
