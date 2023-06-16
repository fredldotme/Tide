import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: settingsDialog
    x: (parent.width - width) / 2
    y: visibility ? ((parent.height - height) / 2) : parent.height
    opacity: visibility ? 1.0 : 0.0
    visible: true
    clip: true

    readonly property bool paneHeight : mainPane.height

    property bool visibility : false

    function show() {
        dialogShadow.opacity = 0.3
        visibility = true
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

    Column {
        id: mainColumn
        anchors.fill: parent

        ToolBar {
            id: consoleToolBar
            width: parent.width

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

        Pane {
            id: mainPane
            width: parent.width
            contentWidth: -1

            Column {
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

