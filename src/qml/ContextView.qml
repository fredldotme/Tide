import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Tide

Rectangle {
    id: contextDialog
    x: (parent.width - width) / 2
    radius: roundedCornersRadius
    y: visibility ? ((parent.height - height) / 2) : parent.height
    opacity: visibility ? 1.0 : 0.0
    visible: opacity > 0.0
    clip: true

    readonly property bool paneHeight : mainPane.height

    property bool visibility : false
    property string currentPath : ""

    signal openRequested()

    function show(path) {
        dialogShadow.opacity = 0.3
        visibility = true
        currentPath = path
        contextFieldSearchText.forceActiveFocus()
        contextResults.model = searchAndReplace.suggestions(contextFieldSearchText.text,
                                                            path)
    }

    function hide() {
        dialogShadow.opacity = 0.0
        visibility = false
    }

    Behavior on y {
        NumberAnimation {
            duration: dialogShadow.consoleAnimation
            easing.type: Easing.OutCubic
        }
    }

    Pane {
        id: mainPane
        anchors.fill: parent
        spacing: paddingMedium
        leftPadding: paddingMedium
        rightPadding: paddingMedium

        Column {
            anchors.fill: parent
            spacing: paddingMedium
            ScrollView {
                id: toolBar
                width: parent.width
                GridLayout {
                    width: parent.width
                    TideToolButton {
                        text: qsTr("Close")
                        onClicked: {
                            contextDialog.hide()
                        }
                        font.bold: true
                        rightPadding: paddingMedium
                    }

                    TextField {
                        id: contextFieldSearchText
                        leftPadding: paddingMedium * 2
                        placeholderText: qsTr("Find:")
                        onTextChanged: {
                            contextResults.model = searchAndReplace.suggestions(text,currentPath)
                        }
                        Layout.preferredWidth: 192
                    }
                    TextField {
                        id: contextFieldReplaceText
                        leftPadding: paddingMedium * 2
                        placeholderText: qsTr("Replace with:")
                        Layout.preferredWidth: 192
                    }

                    TideToolButton {
                        text: qsTr("Replace all")
                        enabled: contextFieldSearchText.text.length > 0
                        onClicked: {
                            let paths = []
                            for (let i = 0; i < contextResults.model.length; i++) {
                                paths.push(contextResults.model[i].path)
                            }

                            searchAndReplace.replace(paths,
                                                     contextFieldSearchText.text,
                                                     contextFieldReplaceText.text)
                            editor.refreshFromDisk()
                        }
                    }
                }
            }

            SearchAndReplace {
                id: searchAndReplace
            }

            ListView {
                id: contextResults
                width: parent.width
                height: parent.height - paddingSmall - toolBar.height
                clip: true
                spacing: paddingSmall
                delegate: ScrollView {
                    width: parent.width
                    ContextViewButton {
                        id: contextResultButton
                        text: modelData.name
                        enabled: true
                        replaceEnabled: contextFieldReplaceText.text.length > 0 && modelData.name.length > 0
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: paddingMedium
                        }
                        color: root.palette.button
                        font.pixelSize: 20
                        isProject: modelData.name.toLowerCase().endsWith(".pro")

                        onReplaceAll: {
                            let list = []
                            list.push(modelData.path);

                            console.log(list)

                            searchAndReplace.replace(list,
                                                     contextFieldSearchText.text,
                                                     contextFieldReplaceText.text)
                            editor.refreshFromDisk()
                            contextResults.model =
                                    searchAndReplace.suggestions(contextFieldSearchText.text,
                                                                 modelData.path)
                        }
                        onOpenClicked: {
                            contextDialog.currentPath = modelData.path
                            contextDialog.openRequested()
                        }
                        onCopyRequested: {
                            console.log("copy requested")
                            const contents = fileIo.readFile(modelData.path)
                            iosSystem.copyToClipboard(contents)
                        }
                        onShareRequested: {
                            const coords = contextResultButton.shareButton.mapToGlobal(0, 0)
                            const pos = Qt.rect(coords.x, coords.y, contextResultButton.width, contextResultButton.height)
                            iosSystem.share("", "file://" + modelData.path, pos)
                        }
                    }
                }
            }
        }
    }
}

