import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: itemRoot
    color: "transparent"
    border.width: outline ? 1 : 0
    border.color: outlineColor
    clip: true

    property color textColor
    property alias label: iconControl
    property alias text: iconControl.text
    property alias font: iconControl.font
    property alias elide: iconControl.elide
    property alias icon: iconControl.icon
    property alias detailText: detailControl.text
    property alias detailControl: detailControl
    property alias mainArea : mainColumn
    property bool flat: true
    property bool pressAnimation : true
    property bool longPressEnabled: true
    property bool outline : false
    property color outlineColor : "transparent"
    property bool selected : false
    readonly property bool pressed: iconControl.pressed || mainMouseArea.pressed
    readonly property bool hasDetailText: detailText !== ""

    signal clicked()
    signal pressAndHold()

    scale: pressed ? 0.9 : 1.0
    opacity: pressed || !enabled ? 0.5 : 1.0

    width: mainColumn.width + (root.paddingMid * 2)
    height: mainColumn.implicitHeight + (root.paddingSmall * 2)

    Behavior on scale {
        NumberAnimation {
            duration: 750
            easing.type: Easing.OutQuad
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 750
            easing.type: Easing.OutQuad
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    Column {
        id: mainColumn
        spacing: root.paddingTiny
        width: parent.width
        height: implicitHeight + (root.paddingSmall * 2)
        y: root.paddingSmall

        TideButton {
            id: iconControl
            flat: itemRoot.flat
            label.color: itemRoot.textColor
            icon.color: itemRoot.textColor
            icon.width: 16
            icon.height: 16
            width: parent.width
            height: implicitHeight

            onClicked: itemRoot.clicked()
            onPressAndHold: {
                if (!longPressEnabled) {
                    itemRoot.clicked()
                    return
                }
                itemRoot.pressAndHold()
            }
        }

        Rectangle {
            width: parent.width - paddingMedium
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            visible: detailControl.visible
            color: itemRoot.textColor
        }

        Label {
            id: detailControl
            font.pixelSize: text === "" ? 0 : 12
            visible: text !== ""
            color: itemRoot.textColor
            horizontalAlignment: Label.AlignHCenter
            verticalAlignment: Label.AlignVCenter

            width: parent.width
            height: detailControl.font.pixelSize + root.paddingTiny

            Behavior on height {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    MouseArea {
        id: mainMouseArea
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
