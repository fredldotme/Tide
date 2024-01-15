import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: itemRoot
    spacing: root.paddingSmall

    property alias label: labelControl
    property alias color: labelControl.color
    property alias text: labelControl.text
    property alias font: labelControl.font
    property alias elide: labelControl.elide
    property alias icon: iconControl.icon
    property bool flat: true
    property bool pressAnimation : true
    property bool longPressEnabled: true
    readonly property bool pressed: iconControl.pressed || labelControlMouseArea.pressed

    signal clicked()
    signal pressAndHold()

    scale: pressed ? 0.9 : 1.0
    opacity: pressed || !enabled ? 0.5 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: labelControlMouseArea.pressAndHoldInterval
            easing.type: Easing.OutQuad
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 750
            easing.type: Easing.OutQuad
        }
    }

    Button {
        id: iconControl
        flat: itemRoot.flat
        onClicked: itemRoot.clicked()
        onPressAndHold: {
            if (!longPressEnabled) {
                itemRoot.clicked()
                return
            }
            itemRoot.pressAndHold()
        }
    }

    Label {
        id: labelControl
        Layout.fillWidth: true
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        MouseArea {
            id: labelControlMouseArea
            anchors.fill: parent
            onClicked: itemRoot.clicked()
            onPressAndHold: {
                if (!longPressEnabled) {
                    itemRoot.clicked()
                    return
                }
                itemRoot.pressAndHold()
            }
        }
    }
}
