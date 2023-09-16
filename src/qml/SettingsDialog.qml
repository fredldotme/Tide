import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TideDialog {
    id: settingsDialog
    clip: true

    readonly property bool paneHeight : mainPane.height

    function show() {
        settingsDialog.open()
    }

    function hide() {
        settingsDialog.close()
    }

    Item {
        id: mainColumn
        anchors.fill: parent

        Item {
            id: consoleToolBar
            width: parent.width
            height: root.topBarHeight

            RowLayout {
                anchors.fill: parent
                Label {
                    Layout.fillWidth: true
                    color: root.palette.text
                    text: qsTr("Settings")
                    elide: Text.ElideRight
                    font.bold: true
                    horizontalAlignment: Label.AlignHCenter
                    verticalAlignment: Label.AlignVCenter
                }

                ToolButton {
                    text: qsTr("Close")
                    font.bold: true
                    rightPadding: paddingMedium
                    onClicked: {
                        settingsDialog.hide()
                    }
                }
            }
        }

        ScrollView {
            id: mainPane
            contentWidth: -1
            anchors {
                top: consoleToolBar.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            Column {
                width: childrenRect.width
                height: childrenRect.height
                spacing: paddingSmall
                RowLayout {
                    Label {
                        text: qsTr("Font size")
                    }
                    ComboBox {
                        id: fontSizeComboBox
                        editable: false
                        model: availableFontSizes
                        currentIndex: settings.fontSize
                        onCurrentIndexChanged: {
                            settings.fontSize = currentIndex
                        }
                    }
                }
                Switch {
                    text: qsTr("Wrap code editor")
                    checked: settings.wrapEditor
                    onCheckedChanged: {
                        settings.wrapEditor = checked
                    }
                }
                Switch {
                    text: qsTr("Wiggle hints")
                    checked: settings.wiggleHints
                    onCheckedChanged: {
                        settings.wiggleHints = checked
                    }
                }
                Switch {
                    id: autocompleteSwitch
                    text: qsTr("Autocomplete (Shift+⌘+S)")
                    checked: settings.autocomplete
                    onCheckedChanged: {
                        settings.autocomplete = checked
                    }
                }
                Switch {
                    id: autoformatSwitch
                    text: qsTr("Formatter (Shift+⌘+F)")
                    checked: settings.autoformat
                    onCheckedChanged: {
                        settings.autoformat = checked
                    }
                }
                Switch {
                    id: clearConsoleSwitch
                    text: qsTr("Clear console output on each run")
                    checked: settings.clearConsole
                    onCheckedChanged: {
                        settings.clearConsole = checked
                    }
                }
                RowLayout {
                    enabled: settings.autoformat
                    Label {
                        text: qsTr("Formatting style")
                    }
                    ComboBox {
                        id: formatStyleComboBox
                        editable: false
                        model: ListModel {
                            ListElement {
                                text: "LLVM"
                            }
                            ListElement {
                                text: "Google"
                            }
                            ListElement {
                                text: "Chromium"
                            }
                            ListElement {
                                text: "GNU"
                            }
                        }
                        currentIndex: settings.formatStyle
                        onCurrentIndexChanged: {
                            settings.formatStyle = currentIndex
                        }
                    }
                }
            }
        }
    }
}

