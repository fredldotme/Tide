import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Tide

Item {
    id: contextDialog
    x: ((parent.width - width - debuggerArea.width) / 2)
    y: visibility ? ((parent.height - height) / 2) : parent.height
    opacity: visibility ? 1.0 : 0.0
    visible: opacity > 0.0

    readonly property bool paneHeight : mainPane.height

    property bool visibility : false
    property string currentPath : ""
    property OpenFilesManager openFiles : null
    property Debugger dbugger : null
    property ExternalProjectPicker projectPicker: null
    property FileIo fileIo : null
    property ProjectBuilder projectBuilder : null

    readonly property bool modal : true

    signal openRequested()

    function show(path) {
        visibility = true
        currentPath = path
        contextFieldSearchText.forceActiveFocus()
        contextResultListView.model = searchAndReplace.suggestions(contextFieldSearchText.text,
                                                                   path)
    }

    function hide() {
        visibility = false
    }

    Component.onCompleted: {
        imFixer.setupImEventFilter(contextFieldSearchText)
        imFixer.setupImEventFilter(contextFieldReplaceText)
    }

    Behavior on y {
        NumberAnimation {
            duration: dialogShadow.consoleAnimation
            easing.type: Easing.OutCubic
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: dialogShadow.consoleAnimation
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: dialogShadow.consoleAnimation
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: mainPane
        width: parent.width
        height: parent.height
        radius: roundedCornersRadius
        color: root.palette.base
        clip: true

        Column {
            width: parent.width
            height: parent.height
            spacing: paddingMedium

            ScrollView {
                id: toolBar
                width: parent.width
                height: root.headerBarHeight

                Grid {
                    x: paddingMedium
                    width: parent.width - paddingSmall
                    height: parent.height

                    TideToolButton {
                        text: qsTr("Close")
                        onClicked: {
                            contextDialog.hide()
                        }
                        font.bold: true
                        rightPadding: paddingMedium
                        height: parent.height
                        width: implicitWidth
                    }

                    TextField {
                        id: contextFieldSearchText
                        leftPadding: paddingMedium * 2
                        placeholderText: qsTr("Find:")
                        onTextChanged: {
                            contextResultListView.model = searchAndReplace.suggestions(text,currentPath)
                        }
                        height: parent.height
                        width: 192
                    }
                    TextField {
                        id: contextFieldReplaceText
                        leftPadding: paddingMedium * 2
                        placeholderText: qsTr("Replace with:")
                        height: parent.height
                        width: 192
                    }

                    TideToolButton {
                        text: qsTr("Replace all")
                        enabled: contextFieldSearchText.text.length > 0
                        height: parent.height
                        width: implicitWidth
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

            property var autoCompleter : AutoCompleter {
                pluginsManager: pluginManager
            }

            ScrollView {
                id: contextResults
                width: parent.width
                height: parent.height - paddingSmall - toolBar.height
                spacing: paddingSmall

                ListView {
                    id: contextResultListView
                    clip: true
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: paddingMedium
                    }
                    height: parent.height
                    onModelChanged: {
                        contextResultListView.currentIndex = 0
                    }
                    spacing: root.paddingSmall
                    delegate: ContextViewButton {
                        id: contextResultButton
                        text: modelData.name
                        enabled: true
                        flat: (contextResultListView.currentIndex !== index)
                        replaceEnabled: contextFieldReplaceText.text.length > 0 && modelData.name.length > 0
                        font.pixelSize: 20
                        isProject: modelData.name.toLowerCase().endsWith(".pro")
                        width: contextResultListView.width
                        height: implicitHeight
                        searchResult: modelData
                        openFiles: contextDialog.openFiles
                        projectPicker: contextDialog.projectPicker
                        projectBuilder: contextDialog.projectBuilder
                        fileIo: contextDialog.fileIo
                        dbugger: contextDialog.dbugger

                        onReplaceAll: {
                            let list = []
                            list.push(modelData.path);

                            console.log(list)

                            searchAndReplace.replace(list,
                                                     contextFieldSearchText.text,
                                                     contextFieldReplaceText.text)
                            editor.refreshFromDisk()
                            contextResultListView.model =
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

    MultiEffect {
        source: mainPane
        anchors.fill: mainPane
        paddingRect: Qt.rect(0, 0, mainPane.width, mainPane.height)
        shadowBlur: 1.0
        shadowEnabled: true
    }
}

