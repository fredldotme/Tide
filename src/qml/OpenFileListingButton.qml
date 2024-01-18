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
    property alias label: labelControl
    property alias text: labelControl.text
    property alias font: labelControl.font
    property alias elide: labelControl.elide
    property alias icon: iconControl.icon
    property alias detailText: detailControl.text
    property alias detailControl: detailControl
    property alias mainArea : mainLayout
    property bool flat: true
    property bool pressAnimation : true
    property bool longPressEnabled: true
    property bool outline : false
    property color outlineColor : "transparent"
    readonly property bool pressed: iconControl.pressed || mainMouseArea.pressed

    signal clicked()
    signal pressAndHold()

    scale: pressed ? 0.9 : 1.0
    opacity: pressed || !enabled ? 0.5 : 1.0

    width: mainLayout.width + (root.paddingMid * 2)
    height: mainLayout.implicitHeight + (root.paddingMid * 2)

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

    RowLayout {
        id: mainLayout
        spacing: root.paddingSmall
        TideButton {
            id: iconControl
            flat: itemRoot.flat
            icon.color: itemRoot.textColor
            onClicked: itemRoot.clicked()
            onPressAndHold: {
                if (!longPressEnabled) {
                    itemRoot.clicked()
                    return
                }
                itemRoot.pressAndHold()
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.fillWidth: true

            Label {
                id: labelControl
                color: itemRoot.textColor
                Layout.fillWidth: true
            }

            Label {
                id: detailControl
                font.pixelSize: detailControl.text === "" ? 0 : 12
                visible: detailControl.text !== ""
                color: itemRoot.textColor
                height: text !== "" ? 16 : 0
                Layout.fillWidth: true
                Behavior on height {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutCubic
                    }
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
