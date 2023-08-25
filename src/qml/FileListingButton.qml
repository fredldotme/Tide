import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: itemRoot

    property alias textColor: labelControl.color
    property alias text: labelControl.text
    property alias font: labelControl.font
    property alias elide: labelControl.elide
    property alias icon: iconControl.icon
    property alias detailText: detailControl.text
    property alias detailControl: detailControl
    property bool flat: true
    property bool pressAnimation : true
    property bool longPressEnabled: true
    readonly property bool pressed: iconControl.pressed || mainMouseArea.pressed

    signal clicked()
    signal pressAndHold()

    scale: pressed ? 0.9 : 1.0
    opacity: pressed || !enabled ? 0.5 : 1.0

    width: mainLayout.width
    height: mainLayout.height

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

    RowLayout {
        id: mainLayout
        spacing: root.paddingSmall
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

        ColumnLayout {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.fillWidth: true

            Text {
                id: labelControl
                Layout.fillWidth: true
            }

            Text {
                id: detailControl
                font.pixelSize: detailControl.text === "" ? 0 : 12
                visible: detailControl.text !== ""
                color: root.palette.text
                Layout.fillWidth: true
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
