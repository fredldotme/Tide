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
    property alias text: categoryButtonLabel.text
    property alias font: categoryButtonLabel.font
    property alias icon: categoryIcon.icon

    property alias mouseArea: mainMouseArea
    property bool pressAnimation : true
    property bool longPressEnabled: true
    property bool outline : false
    property color outlineColor : "transparent"
    readonly property bool pressed: mainMouseArea.pressed
    readonly property bool hovered: mainMouseArea.__hovered
    readonly property int hoverX: mainMouseArea.__hoverX
    readonly property int hoverY: mainMouseArea.__hoverY

    signal clicked()
    signal pressAndHold()

    scale: pressed ? 0.9 : 1.0
    opacity: pressed || !enabled ? 0.5 : 1.0

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

    Row {
        id: mainLayout
        spacing: root.paddingSmall
        anchors.fill: parent
        anchors.margins: paddingSmall

        Row {
            width: parent.width
            spacing: paddingSmall

            Button {
                id: categoryIcon
                flat: true
                icon.color: itemRoot.textColor
                height: parent.height
                width: height
            }
            Label {
                id: categoryButtonLabel
                color: itemRoot.textColor
            }
        }
    }

    MouseArea {
        id: mainMouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: itemRoot.clicked()
        onPressAndHold: {
            if (!longPressEnabled) {
                itemRoot.clicked()
                return
            }
            itemRoot.pressAndHold()
        }

        property bool __hovered : false
        property int __hoverX: mouseX
        property int __hoverY: mouseY

        onContainsMouseChanged: {
            __hovered = containsMouse;
        }
        onEntered: {
            __hovered = true;
        }
        onExited: {
            __hovered = false;
        }
    }
}
