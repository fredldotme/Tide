import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsDialog
    x: (parent.width - width) / 2
    radius: roundedCornersRadius
    y: visibility ? ((parent.height - height) / 2) : parent.height
    opacity: visibility ? 1.0 : 0.0
    visible: true
    clip: true

    readonly property bool paneHeight : mainColumn.height

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
                        model: ListModel {
                            ListElement {
                                text: "10"
                            }
                            ListElement {
                                text: "12"
                            }
                            ListElement {
                                text: "14"
                            }
                            ListElement {
                                text: "16"
                            }
                            ListElement {
                                text: "18"
                            }
                            ListElement {
                                text: "20"
                            }
                            ListElement {
                                text: "22"
                            }
                            ListElement {
                                text: "24"
                            }
                        }
                        onCurrentIndexChanged: {
                            settings.fontSize = parseInt(currentText)
                        }
                    }
                }
                Switch {
                    id: autocompleteSwitch
                    text: qsTr("Autocomplete (Shift+cmd+S)")
                    checked: settings.autocomplete
                    onCheckedChanged: {
                        settings.autocomplete = checked
                    }
                }
                Switch {
                    id: autoformatSwitch
                    text: qsTr("Formatter (cmd+F)")
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

                        onCurrentIndexChanged: {
                            settings.formatStyle = currentIndex
                        }
                    }
                }
            }
        }

        Component.onCompleted: {
            // Format style
            formatStyleComboBox.currentIndex = settings.formatStyle

            // Font size
            let index = 0;
            for (let data in fontSizeComboBox.model) {
                if (parseInt(data.text) === settings.fontSize) {
                    fontSizeComboBox.currentIndex = index;
                    return;
                }
                ++index;
            }
            fontSizeComboBox.currentIndex = 2;
        }
    }
}

