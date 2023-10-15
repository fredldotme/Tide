import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: dialogRoot
    x: ((parent.width - width - debuggerArea.width) / 2)
    y: visibility ? ((parent.height - height) / 2) : parent.height
    opacity: visibility ? 1.0 : 0.0
    visible: opacity > 0.0

    property bool visibility : false

    Behavior on y {
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

    function show() {
        visibility = true
    }

    function hide() {
        visibility = false
    }

    Rectangle {
        id: dialogMainView
        anchors.fill: parent
        color: root.palette.base
        radius: roundedCornersRadius

        Row {
            id: headerRow
            x: paddingSmall
            width: parent.width
            spacing: paddingSmall

            TideToolButton {
                id: closeButton
                text: qsTr("Close")
                onClicked: dialogRoot.hide()
                height: parent.height
            }

            TabBar {
                id: bar
                width: parent.width - closeButton.width - paddingMedium - roundedCornersRadius
                TabButton {
                    text: qsTr("Status")
                }
                TabButton {
                    text: qsTr("Commit")
                }
                TabButton {
                    text: qsTr("Logs")
                }
            }
        }

        StackLayout {
            y: headerRow.height
            width: parent.width
            height: parent.height - headerRow.height

            currentIndex: bar.currentIndex
            Item {
                id: statusTab

                Column {
                    width: (parent.width / 3) * 2
                    anchors.centerIn: parent
                    spacing: paddingSmall
                    Row {
                        spacing: paddingSmall
                        width: parent.width
                        Text {
                            width: implicitWidth
                            text: qsTr("Current branch:")
                            font.bold: true
                            color: root.palette.text
                        }
                        Text {
                            width: implicitWidth
                            text: git.status.currentBranch
                            color: root.palette.text
                        }
                    }
                    Text {
                        width: parent.width
                        text: qsTr("Remotes:")
                        font.bold: true
                        color: root.palette.text
                    }
                    Repeater {
                        id: remotesRepeater
                        width: parent.width
                        model: git.status.remotes
                        delegate: Column {
                            y: paddingSmall
                            width: parent.width
                            spacing: paddingSmall
                            Row {
                                width: parent.width
                                Text {
                                    width: implicitWidth
                                    text: qsTr("Name:")
                                    font.bold: true
                                    color: root.palette.text
                                }
                                Text {
                                    width: implicitWidth
                                    text: modelData.name
                                    color: root.palette.text
                                }
                            }
                            Row {
                                width: parent.width
                                Text {
                                    width: implicitWidth
                                    text: qsTr("Fetch:")
                                    font.bold: true
                                    color: root.palette.text
                                }
                                Text {
                                    width: implicitWidth
                                    text: modelData.fetch
                                    color: root.palette.text
                                }
                            }
                            Row {
                                width: parent.width
                                Text {
                                    width: implicitWidth
                                    text: qsTr("Push:")
                                    font.bold: true
                                    color: root.palette.text
                                }
                                Text {
                                    width: implicitWidth
                                    text: modelData.push
                                    color: root.palette.text
                                }
                            }
                        }
                    }
                }
            }
            Item {
                id: commitTab
            }

            Column {
                id: logsTab
                spacing: paddingSmall

                Row {
                    id: branchSelection
                    width: parent.width
                    spacing: paddingMedium
                    Label {
                        text: qsTr("Branch:")
                        height: branchComboBox.height
                        horizontalAlignment: Label.AlignHCenter
                        verticalAlignment: Label.AlignVCenter
                    }
                    ComboBox {
                        id: branchComboBox
                        z: paddedOverlayArea.contextMenuZ
                        height: implicitHeight
                        model: git.status.branches
                        editable: false
                        onCurrentIndexChanged: {
                            commitLogs.model = git.logs(currentValue)
                        }
                    }
                }

                ListView {
                    id: commitLogs
                    width: parent.width
                    height: parent.height - branchSelection.height
                    clip: true
                    spacing: paddingSmall
                    model: {
                        return git.logs(git.status.branch)
                    }
                    delegate: GitLogEntry {
                        width: commitLogs.width
                        height: paddingSmall +
                                Math.max(label.height, boldLabel.height) +
                                paddingSmall +
                                detailControl.font.pixelSize +
                                paddingSmall +
                                (expanded ? expandedControl.height + paddingSmall : 0)
                        radius: roundedCornersRadiusSmall
                        font.pixelSize: 18
                        outline: true
                        outlineColor: root.palette.button
                        boldText: modelData.committer
                        text: modelData.summary
                        detailText: modelData.commit
                        expandedText: expanded ? modelData.message : ""
                        textColor: expanded ? root.palette.active.buttonText :
                                              root.palette.text
                        color: expanded ?
                                   root.palette.active.button :
                                   "transparent"
                        onClicked: {
                            expanded = !expanded
                        }
                    }
                }
            }
        }
    }

    MultiEffect {
        source: dialogMainView
        anchors.fill: dialogMainView
        paddingRect: Qt.rect(0, 0, dialogMainView.width, dialogMainView.height)
        shadowBlur: 1.0
        shadowEnabled: true
    }
}
