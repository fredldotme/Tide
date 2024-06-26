import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: itemRoot
    color: "transparent"
    border.width: outline ? 1 : 0
    border.color: outlineColor
    clip: true

    property bool expanded : false
    property alias expandedControl : expandedControl
    property alias expandedText : expandedControl.text

    property color textColor
    property alias label: labelControl
    property alias text: labelControl.text
    property alias font: labelControl.font
    property alias elide: labelControl.elide

    property alias boldLabel: boldLabelControl
    property alias boldText: boldLabelControl.text

    property alias detailText: detailControl.text
    property alias detailControl: detailControl

    property alias mouseArea: mainMouseArea
    property bool flat: true
    property bool pressAnimation : true
    property bool longPressEnabled: true
    property bool outline : false
    property color outlineColor : "transparent"
    readonly property bool pressed: mainMouseArea.pressed
    readonly property bool hovered: mainMouseArea.__hovered
    readonly property int hoverX: mainMouseArea.__hoverX
    readonly property int hoverY: mainMouseArea.__hoverY

    property alias checked : checkBox.checked

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
        anchors.fill: parent
        anchors.margins: paddingSmall
        spacing: paddingMid

        CheckBox {
            id: checkBox
            width: 64
            height: parent.height
        }

        Column {
            spacing: root.paddingSmall
            width: parent.width - checkBox.width - paddingMid
            height: parent.height

            ColumnLayout {
                width: parent.width

                RowLayout {
                    width: parent.width
                    Label {
                        id: boldLabelControl
                        color: itemRoot.textColor
                        textFormat: Text.PlainText
                        font.bold: true
                    }
                    Label {
                        id: labelControl
                        color: itemRoot.textColor
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                    }
                }

                Label {
                    id: detailControl
                    font.pixelSize: detailControl.text === "" ? 0 : 12
                    visible: detailControl.text !== ""
                    color: itemRoot.textColor
                    width: parent.width
                    height: text !== "" ? 16 : 0
                    textFormat: Text.StyledText

                    Behavior on height {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
            Label {
                id: expandedControl
                font.pixelSize: expandedControl.text === "" ? 0 : 14
                visible: expandedControl.text !== ""
                color: itemRoot.textColor
                width: parent.width
                height: implicitHeight
                textFormat: Text.MarkdownText
                wrapMode: Text.WrapAnywhere

                Behavior on height {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: mainMouseArea
                anchors.fill: expandedControl
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
    }
}
