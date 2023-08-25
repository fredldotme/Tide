import QtQuick
import QtQuick.Controls

Dialog {
    clip: true
    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 40
        color: root.tidePalette.base
        border.color: root.tidePalette.dark
        radius: roundedCornersRadius
    }
}
