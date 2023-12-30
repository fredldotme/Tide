import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

TideDialog {
    id: dialogRoot

    readonly property alias model : commitLogs.model

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
        dialogRoot.open()
        git.refreshStatus()
        commitLogs.model = git.logs(branchComboBox.model[branchComboBox.currentIndex])
        branchComboBox.model = git.status.branches
    }

    function hide() {
        dialogRoot.close()
    }

    Row {
        id: headerRow
        x: paddingSmall
        width: parent.width
        spacing: paddingSmall

        TideToolButton {
            id: closeButton
            text: qsTr("Close")
            font.bold: true
            onClicked: dialogRoot.hide()
            height: parent.height
        }

        TabBar {
            id: bar
            width: parent.width - closeButton.width - paddingMedium - roundedCornersRadius
            background: Rectangle {
                color: root.palette.base
            }
            /*TabButton {
                    text: qsTr("Status")
                }*/
            /*TabButton {
                    text: qsTr("Commit")
                }*/
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
        /*Item {
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
            }*/

        /*Item {
                id: commitTab
                readonly property bool hasCommittable : git.hasCommittable

                Label {
                    anchors.fill: parent
                    text: qsTr("Nothing to commit")
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    visible: !commitTab.hasCommittable
                }

                Column {
                    anchors.fill: parent
                    spacing: paddingSmall
                    visible: commitTab.hasCommittable

                    ToolBar {
                        width: parent.width
                        height: toolBarHeight

                        TideToolButton {
                            text: qsTr("Proceed")
                            enabled: git.hasCommittable
                            onClicked: git.commit();
                        }
                        TideToolButton {
                            text: qsTr("Reset stage")
                            enabled: git.hasStagedFiles
                            onClicked: git.resetStage();
                        }
                    }
                }
            }*/

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
                    width: implicitWidth
                    height: implicitHeight
                    model: git.status.branches
                    editable: false
                    onCurrentIndexChanged: {
                        commitLogs.model = git.logs(currentValue)
                    }
                    popup.background: Rectangle {
                        implicitWidth: 200
                        implicitHeight: branchComboBox.contentItem.implicitHeight
                        color: root.palette.window
                        radius: roundedCornersRadiusSmall
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
                    detailText: modelData.timestamp
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
