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
    property alias iconWidth: iconControl.icon.width
    property alias iconHeight: iconControl.icon.height
    property alias detailText: detailControl.text
    property alias detailControl: detailControl
    property alias contentItem: mainColumn
    property bool flat: true
    property bool pressAnimation : true
    property bool longPressEnabled: true
    property bool showTrailingSeparator : false

    readonly property bool pressed: iconControl.pressed || mainMouseArea.pressed
    readonly property int padding: root.paddingSmall

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

    Column {
        id: mainColumn
        width: parent.width
        height: implicitHeight - itemRoot.padding

        RowLayout {
            id: mainLayout
            spacing: root.paddingSmall
            width: parent.width
            height: implicitHeight

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

                Label {
                    id: labelControl
                    wrapMode: Label.WrapAtWordBoundaryOrAnywhere
                    Layout.fillWidth: true
                }

                Label {
                    id: detailControl
                    font.pixelSize: detailControl.text === "" ? 0 : 12
                    visible: detailControl.text !== ""
                    color: root.palette.text
                    Layout.fillWidth: true
                }
            }
        }

        Item {
            width: parent.width
            height: itemRoot.padding * 2

            Rectangle {
                visible: itemRoot.showTrailingSeparator
                width: parent.width - (paddingMedium * 2)
                height: 1
                anchors.centerIn: parent
                color: root.palette.midlight
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
