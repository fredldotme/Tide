import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: consoleView
    color: root.palette.base
    radius: roundedCornersRadius
    x: (parent.width - width) / 2
    y: visibility ? ((parent.height - height) / 2) : parent.height
    opacity: visibility ? 1.0 : 0.0
    border.color: root.palette.text
    border.width: 1
    visible: true
    clip: true

    property alias consoleOutput : consoleOutput
    property alias consoleScrollView : consoleScrollView

    property bool hideStdOut: false
    property bool visibility : false

    function show() {
        dialogShadow.opacity = 0.3
        visibility = true;
        hideStdOut = false
    }

    function hide() {
        dialogShadow.opacity = 0.0
        visibility = false
    }

    ListModel {
        id: consoleOutput
    }

    Behavior on y {
        NumberAnimation {
            duration: dialogShadow.consoleAnimation
            easing.type: Easing.OutCubic
        }
    }

    Column {
        anchors.fill: parent
        clip: true

        ToolBar {
            id: consoleToolBar
            width: parent.width
            RowLayout {
                anchors.fill: parent
                ToolButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/xmark.circle@2x.png")
                    icon.color: root.palette.button
                    leftPadding: paddingMedium
                    onClicked: {
                        clearConsoleOutput()
                    }
                }
                ToolButton {
                    icon.source: !consoleView.hideStdOut ?
                                     Qt.resolvedUrl("qrc:/assets/line.3.horizontal.decrease.circle@2x.png")
                                   : Qt.resolvedUrl("qrc:/assets/line.3.horizontal.decrease.circle.fill@2x.png")
                    icon.color: !consoleView.hideStdOut ? root.palette.link : root.palette.linkVisited
                    onClicked: {
                        consoleView.hideStdOut = !consoleView.hideStdOut
                    }
                }

                Label {
                    Layout.fillWidth: true
                    color: root.palette.text
                    text: qsTr("Console")
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
                        consoleView.hide()
                    }
                }
            }
        }

        ScrollView {
            width: parent.width
            height: parent.height - consoleToolBar.height - consoleInputField.height - (paddingSmall*2)
            ListView {
                id: consoleScrollView
                model: consoleOutput
                width: parent.width
                clip: true
                delegate: Text {
                    readonly property bool isAllowedLine: !stdout || (stdout && !consoleView.hideStdOut)
                    id: consoleContentLine
                    wrapMode: TextArea.WrapAnywhere
                    font: fixedFont
                    text: content
                    color: root.palette.text
                    width: consoleScrollView.width
                    height: isAllowedLine ? contentHeight : 0
                    visible: height > 0

                    Behavior on height {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }

                    Connections {
                        target: consoleView
                        function onHideStdOutChanged() {
                            consoleContentLine.height =
                                    consoleContentLine.isAllowedLine ?
                                        consoleContentLine.contentHeight : 0
                        }
                    }
                }
            }
        }

        TextField {
            id: consoleInputField
            font: fixedFont
            width: parent.width
            height: font.pixelSize + (paddingSmall*2)
            background: Item { }
            placeholderText: qsTr("Input:")
            focus: consoleView.visibility
            onAccepted: {
                consoleHandler.write(text + "\n")
                clear()
                forceActiveFocus()
            }
            Component.onCompleted: {
                imFixer.setupImEventFilter(consoleInputField)
            }
        }
    }
}

