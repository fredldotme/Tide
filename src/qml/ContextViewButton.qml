import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Grid {
    id: itemRoot
    spacing: root.paddingMedium

    property var color : root.palette.button
    property alias text: labelControl.text
    property alias font: labelControl.font
    property alias elide: labelControl.elide
    property alias shareButton: shareButton

    property bool flat: true
    property bool pressAnimation : true
    property bool longPressEnabled: true
    property bool replaceEnabled: true

    signal replaceAll()
    signal openClicked()
    signal copyRequested()
    signal firstOccurance()
    signal shareRequested()

    Button {
        id: shareButton
        icon.source: Qt.resolvedUrl("qrc:/assets/square.and.arrow.up@2x.png")
        icon.width: 48
        icon.height: 48
        width: 48
        height: 48
        flat: true
        onClicked: itemRoot.shareRequested()
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter
        Label {
            id: labelControl
            color: root.palette.text
        }

        Row {
            spacing: paddingSmall

            Button {
                id: openButton
                text: qsTr("Open")
                onClicked: itemRoot.openClicked()
            }
            Button {
                id: firstOccuranceButton
                text: qsTr("Copy")
                onClicked: itemRoot.copyRequested()
            }
            Button {
                id: replaceAllButton
                text: qsTr("Replace all")
                onClicked: itemRoot.replaceAll()
            }
        }
    }
}
