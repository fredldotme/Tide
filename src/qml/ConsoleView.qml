import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: consoleView

    readonly property int debuggerPaddingX :
        integratedMode ? 0 : parent != consoleViewDialogLandingPad ? debuggerArea.width : 0
    readonly property int headerPaddingY :
        integratedMode ? 0 : parent != consoleViewDialogLandingPad && !root.landscapeMode ? root.headerItemHeight : 0

    property bool integratedMode : false
    onIntegratedModeChanged: {
        visibility = integratedMode
    }
    property bool expanded : false

    x: integratedMode ? 0 : ((parent.width - width - debuggerPaddingX) / 2)
    y: integratedMode ? 0 : visibility ? ((parent.height - height) / 2) + headerPaddingY : parent.height
    opacity: visibility ? opacityOverride : 0.0
    visible: opacity > 0.0

    property alias consoleOutput : consoleOutput
    property alias consoleScrollView : consoleScrollView

    property bool hideStdOut: false
    property bool visibility : false
    property real opacityOverride : 1.0
    property bool inputEnabled : false
    property bool fullScreenMode : false

    readonly property bool modal : true

    function show() {
        if (integratedMode)
            expanded = true

        visibility = true;
        hideStdOut = false
    }

    function hide() {
        if (integratedMode)
            expanded = false

        visibility = false
    }

    ListModel {
        id: consoleOutput
        onCountChanged: {
            if (consoleView.visibility && inputEnabled) {
                consoleInputField.focus = true
            }
        }
    }

    Timer {
        id: delayedRefocus
        interval: 50
        repeat: false
        onTriggered: {
            if (consoleView.visibility && inputEnabled) {
                consoleInputField.focus = true
            }
        }
    }

    Behavior on y {
        enabled: !integratedMode
        NumberAnimation {
            duration: dialogShadow.consoleAnimation
            easing.type: Easing.OutCubic
        }
    }
    Behavior on width {
        enabled: !integratedMode
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
        id: consoleRect
        anchors.fill: parent
        color: root.palette.base
        border.color: root.borderColor
        border.width: 1
        radius: roundedCornersRadiusMedium
        clip: true

        Column {
            id: consoleRectColumn
            anchors.fill: parent
            clip: true

            Item {
                id: consoleToolBar
                width: parent.width
                height: root.toolBarHeight

                RowLayout {
                    anchors.fill: parent
                    TideToolButton {
                        enabled: ((integratedMode && expanded) || !integratedMode) && consoleOutput.count > 0
                        visible: enabled
                        icon.source: Qt.resolvedUrl("qrc:/assets/xmark.circle@2x.png")
                        icon.color: root.palette.button
                        leftPadding: paddingMedium
                        onClicked: {
                            clearConsoleOutput()
                        }
                    }
                    TideToolButton {
                        enabled: ((integratedMode && expanded) || !integratedMode) && consoleOutput.count > 0
                        visible: enabled
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
                        text: qsTr("Stop")
                        enabled: !integratedMode
                        visible: !integratedMode && (wasmRunner.running || pyRunner.running)
                        font.bold: true
                        onClicked: {
                            if (wasmRunner)
                                wasmRunner.kill()
                            if (pyRunner)
                                pyRunner.kill()
                        }
                    }
                    ToolButton {
                        text: qsTr("Hide")
                        enabled: !integratedMode
                        visible: !integratedMode
                        font.bold: true
                        rightPadding: paddingMedium
                        onClicked: {
                            consoleView.hide()
                        }
                    }
                    ToolButton {
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: paddingMedium
                        Layout.topMargin: expanded ? paddingSmall : 0
                        visible: integratedMode
                        enabled: integratedMode
                        icon.source: expanded ?
                                         Qt.resolvedUrl("qrc:/assets/chevron.compact.down@2x.png") :
                                         Qt.resolvedUrl("qrc:/assets/chevron.compact.up@2x.png")
                        icon.width: 32
                        icon.height: 32
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        font.pixelSize: 16
                        onClicked: {
                            expanded = !expanded
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
                        textFormat: Text.PlainText
                        wrapMode: TextArea.WrapAnywhere
                        font: fixedFont
                        text: content
                        color: root.palette.text
                        width: consoleScrollView.width
                        height: isAllowedLine ? contentHeight : 0
                        opacity: isAllowedLine ? 1.0 : 0.0
                        visible: height > 0

                        Behavior on height {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
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
                enabled: consoleView.inputEnabled && ((integratedMode && expanded) || !integratedMode)
                height: enabled ? font.pixelSize + (paddingMid * 2) : 0
                visible: height > 0
                background: Item { }
                placeholderText: qsTr("Input:")
                focus: consoleView.visibility && enabled

                Behavior on height {
                    NumberAnimation {
                        easing.type: Easing.OutQuint
                        duration: 100
                    }
                }

                onAccepted: {
                    consoleHandler.write(text + "\n")
                    if (consoleOutput.count > 0) {
                        consoleOutput.get(consoleOutput.count - 1).content += (text + "\n")
                    } else {
                        consoleOutput.append({"content": text, "stdout": true})
                    }
                    clear()
                    delayedRefocus.restart()
                }
                Component.onCompleted: {
                    imFixer.setupImEventFilter(consoleInputField)
                }
            }
        }

        Label {
            font: fixedFont
            text: !inputEnabled ? qsTr("Nothing running in the console yet.") :
                                  qsTr("Waiting for output...")
            visible: consoleOutput.count === 0 && (integratedMode && expanded)
            anchors.fill: parent
            horizontalAlignment: Label.AlignHCenter
            verticalAlignment: Label.AlignVCenter
            wrapMode: Label.WrapAnywhere
        }
    }

    MultiEffect {
        source: consoleRect
        anchors.fill: consoleRect
        paddingRect: Qt.rect(0, 0, consoleRect.width, consoleRect.height)
        shadowBlur: 1.0
        shadowEnabled: true
        visible: !integratedMode
    }
}

