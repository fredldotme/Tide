import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import Tide

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
        gitFilesList.reloadModel()
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
            //TabButton {
            //    text: qsTr("Status")
            //}
            TabButton {
                text: qsTr("Logs")
            }
            TabButton {
                text: qsTr("Commit")
            }
        }
    }

    StackLayout {
        y: headerRow.height
        width: parent.width
        height: parent.height - headerRow.height
        currentIndex: bar.currentIndex

        /*
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
                        font.pixelSize: 24
                        color: root.palette.text
                    }
                    Text {
                        width: implicitWidth
                        text: git.status.currentBranch
                        font.pixelSize: 24
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
                    model: git.status.remotes
                    delegate: Column {
                        x: paddingLarge
                        y: paddingSmall
                        width: parent.width
                        height: implicitHeight + paddingMedium
                        spacing: paddingSmall
                        Row {
                            width: parent.width
                            Label {
                                width: implicitWidth
                                text: qsTr("Name:")
                                font.pixelSize: 24
                                font.bold: true
                                color: root.palette.text
                            }
                            Label {
                                width: implicitWidth
                                text: modelData.name
                                font.pixelSize: 24
                                color: root.palette.text
                            }
                        }
                        Row {
                            width: parent.width
                            Label {
                                width: implicitWidth
                                text: qsTr("Fetch:")
                                font.bold: true
                                font.pixelSize: 24
                                color: root.palette.text
                            }
                            Label {
                                width: implicitWidth
                                text: modelData.fetch
                                font.pixelSize: 24
                                color: root.palette.text
                            }
                        }
                        Row {
                            width: parent.width
                            Label {
                                width: implicitWidth
                                text: qsTr("Push:")
                                font.bold: true
                                font.pixelSize: 24
                                color: root.palette.text
                            }
                            Label {
                                width: implicitWidth
                                text: modelData.push
                                font.pixelSize: 24
                                color: root.palette.text
                            }
                        }
                    }
                }
            }
        }
        */

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
                    git.hasCommittable
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

        Item {
            id: commitTab
            readonly property bool hasCommittable : git.hasCommittable

            Label {
                anchors.fill: parent
                text: qsTr("Nothing to commit")
                font.pixelSize: 32
                color: root.palette.placeholderText
                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter
                visible: !commitTab.hasCommittable
            }

            Column {
                anchors.fill: parent
                anchors.margins: paddingMedium
                spacing: paddingSmall
                visible: commitTab.hasCommittable

                RowLayout {
                    width: parent.width

                    Label {
                        id: titleLabel
                        text: qsTr("Title:")
                        Layout.preferredWidth: Math.max(implicitWidth,
                                                        messageLabel.implicitWidth)
                    }

                    TextField {
                        id: summary
                        Layout.fillWidth: true

                        Component.onCompleted: {
                            imFixer.setupImEventFilter(summary)
                        }
                    }
                }

                RowLayout {
                    width: parent.width

                    Label {
                        id: messageLabel
                        text: qsTr("Message:")
                        Layout.preferredWidth: Math.max(implicitWidth,
                                                        titleLabel.implicitWidth)
                    }

                    ScrollView {
                        id: bodyContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: body.font.pixelSize * 4

                        TextArea {
                            id: body
                            width: parent.width
                            height: implicitHeight

                            Component.onCompleted: {
                                imFixer.setupImEventFilter(body)
                            }
                        }
                    }
                }

                ListView {
                    id: gitFilesList
                    width: parent.width
                    height: parent.height -
                            toolBarHeight -
                            bodyContainer.height -
                            summary.height

                    function reloadModel() {
                        model = git.files
                    }

                    clip: true
                    spacing: paddingSmall

                    delegate: GitFileEntry {
                        width: gitFilesList.width
                        height: paddingSmall +
                                Math.max(label.height, boldLabel.height) +
                                paddingSmall +
                                detailControl.font.pixelSize +
                                paddingSmall +
                                (expanded ? expandedControl.height + paddingSmall : 0)
                        text: modelData.path
                        checked: modelData.staged
                        radius: roundedCornersRadiusSmall
                        outline: true
                        outlineColor: root.palette.button
                        textColor: expanded ? root.palette.active.buttonText :
                                              root.palette.text
                        color: expanded ?
                                   root.palette.active.button :
                                   "transparent"

                        onCheckedChanged: {
                            if (checked)
                                git.stage(modelData.path)
                            else
                                git.unstage(modelData.path)
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    height: toolBarHeight

                    TideToolButton {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        text: qsTr("Commit")
                        enabled: summary.text !== "" && git.hasStagedFiles
                        onClicked: {
                            git.commit(summary.text, body.text);
                            summary.text = ""
                            body.text = ""
                        }
                    }
                }
            }
        }
    }
}
