import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: itemRoot
    spacing: root.paddingSmall

    property alias color: labelControl.color
    property alias text: labelControl.text
    property alias font: labelControl.font
    property alias elide: labelControl.elide
    property alias icon: iconControl.icon
    readonly property bool pressed: iconControl.pressed || labelControlMouseArea.pressed
    property bool flat: true

    signal clicked()
    signal pressAndHold()

    Button {
        id: iconControl
        flat: itemRoot.flat
        onClicked: itemRoot.clicked()
        onPressAndHold: itemRoot.pressAndHold()
    }

    Text {
        id: labelControl
        Layout.fillWidth: true
        MouseArea {
            id: labelControlMouseArea
            anchors.fill: parent
            onClicked: itemRoot.clicked()
            onPressAndHold: itemRoot.pressAndHold()
        }
    }
}
