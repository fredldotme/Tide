import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Column {
    id: itemRoot

    property alias text: labelControl.text
    property alias font: labelControl.font
    property alias elide: labelControl.elide
    property alias shareButton: shareButton

    property bool flat: true
    property bool pressAnimation : true
    property bool longPressEnabled: true
    property bool replaceEnabled: true
    property bool isProject : false

    signal replaceAll()
    signal openClicked()
    signal copyRequested()
    signal firstOccurance()
    signal shareRequested()

    spacing: root.paddingMedium

    Row {
        width: parent.width
        height: implicitHeight

        Button {
            id: shareButton
            icon.source: isProject ?
                             Qt.resolvedUrl("qrc:/assets/hammer@2x.png")
                           : Qt.resolvedUrl("qrc:/assets/doc@2x.png")
            icon.width: 48
            icon.height: 48
            width: 48
            height: 48
            flat: true
            enabled: false
        }

        Column {
            height: parent.height
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

    Column {
        width: parent.width
        height: implicitHeight

        Repeater {
            CodeEditor {

            }
        }
    }
}
