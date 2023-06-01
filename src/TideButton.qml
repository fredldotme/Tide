import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: itemRoot
    spacing: root.paddingSmall

    property alias color: labelControl.color
    property alias text: labelControl.text
    property alias font: labelControl.font
    property alias icon: iconControl.icon
    readonly property bool pressed: iconControl.pressed || labelControlMouseArea.pressed

    signal clicked()
    signal pressAndHold()

    Button {
        id: iconControl
        flat: true
        onClicked: itemRoot.clicked()
        onPressAndHold: itemRoot.pressAndHold()
    }

    Text {
        id: labelControl
        MouseArea {
            id: labelControlMouseArea
            anchors.fill: parent
            onClicked: itemRoot.clicked()
            onPressAndHold: itemRoot.pressAndHold()
        }
    }
}
