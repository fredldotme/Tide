import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Tide

Row {
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
    property var searchResult : null
    property OpenFilesManager openFiles: null
    property ExternalProjectPicker projectPicker: null
    property FileIo fileIo : null
    property Debugger dbugger : null
    property ProjectBuilder projectBuilder : null

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
            height: implicitHeight
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

    Item {
        width: parent.width
        height: implicitHeight

        ListView {
            id: occurancesListView
            model: itemRoot.searchResult.occurances
            width: parent.width
            height: implicitHeight

            delegate: CodeEditor {
                file: itemRoot.openFiles.open(itemRoot.searchResult.path)
                codeField.readOnly: true
                focus: false
                projectPicker: itemRoot.projectPicker
                fileIo: itemRoot.fileIo
                openFiles: itemRoot.openFiles
                dbugger: itemRoot.dbugger
                projectBuilder : itemRoot.projectBuilder
                width: parent.width
                height: fixedFont.pixelSize * 5
                Component.onCompleted: console.log("OCCURANCE THERE " + index)
            }
        }
    }
}
