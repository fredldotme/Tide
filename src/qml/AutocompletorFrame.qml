import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Tide

Item {
    id: autoCompletorRoot

    property alias list : autoCompletionList
    property alias frame: autoCompletorFrame
    property string text: input.text

    property var input: null
    property DirectoryListing fileHint : null
    property ProjectBuilder projectBuilder : null
    property int typeFilter : AutoCompleter.Unspecified

    AutoCompleter {
        id: autoCompleter
        pluginsManager: pluginManager

        onDeclsChanged: {
            console.log("'Add Breakpoint' decls changed");
        }
    }

    readonly property string projectName : {
        let target = qsTr("project");
        const crumbs = projectBuilder.projectFile.split('/');
        if (crumbs.length > 0) {
            target = crumbs[crumbs.length - 1]
        }
        return target
    }

    function reload() {
        // Old State: libclang and clang++ trip over each other regularly.
        // New State: iOS enablement in LLVM has ManagedStatic as thread-local, should not happen as much anymore
        //if (projectBuilder.building)
        //    return;

        autoCompleter.setIncludePaths(projectBuilder.includePaths());
        autoCompleter.setSysroot(sysroot)

        // TODO: Extend to variables/constants when watchpoints are in
        autoCompleter.reloadAst(projectBuilder.sourceFiles,
                                "",
                                AutoCompleter.Function | AutoCompleter.Method,
                                /*codeField.currentLine*/ 0,
                                /*codeField.currentColumn*/ 0)
    }

    Item {
        id: autoCompletorFrame

        Behavior on x {
            NumberAnimation {
                duration: autoCompletorFrame.state === "compact" ?
                              100 : 200
                easing.type: Easing.OutExpo
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: autoCompletorFrame.state === "compact" ?
                              100 : 200
                easing.type: Easing.OutExpo
            }
        }

        state: "compact"
        states: [
            State {
                name: "compact"
                PropertyChanges {
                    target: autoCompletorFrame
                    x: parent.x
                    y: parent.y
                }
            },
            State {
                name: "expanded"
                PropertyChanges {
                    target: autoCompletorFrame
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2
                }
            }
        ]
        transitions: [
            Transition {
                from: "compact"
                to: "expanded"
                ParallelAnimation {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutExpo
                    }
                }
            },
            Transition {
                from: "expanded"
                to: "compact"
                ParallelAnimation {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutExpo
                    }
                }
            }
        ]

        anchors.fill: parent

        Component.onCompleted: {
            imFixer.setupImEventFilter(input)
        }

        Item {
            id: autoCompletorContent
            width: parent.width
            height: parent.height

            Label {
                text: qsTr("Nothing found")
                font.pixelSize: 24
                color: root.palette.text
                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter
                width: autoCompletorFrame.width
                height: parent.height
                visible: autoCompletionList.model.length === 0
            }

            ScrollView {
                id: autoCompletionScrollView
                width: parent.width
                height: parent.height
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                ListView {
                    id: autoCompletionList
                    model: autoCompletorFrame.state !== "compact" && input.text !== "" ?
                               autoCompleter.filteredDecls(input.text) :
                               autoCompletorFrame.state === "compact" && input.text !== "" ?
                                   autoCompleter.filteredDecls(input.text) :
                                   autoCompleter.decls
                    contentWidth: contentItem.childrenRect.width
                    contentHeight: contentItem.childrenRect.height
                    width: parent.width
                    height: parent.height
                    clip: true

                    onModelChanged: {
                        console.log("Autocompletion model changed");
                    }

                    function iconForKind(kind) {
                        if (kind === AutoCompleter.Function)
                            return Qt.resolvedUrl("qrc:/assets/function@2x.png");
                        else if (kind === AutoCompleter.Variable ||
                                 kind === AutoCompleter.Parameter)
                            return Qt.resolvedUrl("qrc:/assets/v.square@2x.png");
                        return ""
                    }

                    delegate: TidePrefixedButton {
                        width: autoCompletorFrame.width
                        icon.source: autoCompletionList.iconForKind(modelData.kind)
                        prefix: modelData.prefix
                        text: modelData.name
                        detail: modelData.detail !== "" ? qsTr("inside %1").arg(modelData.detail) :
                                                          qsTr("in %1").arg(autoCompletorRoot.projectName)
                        font.styleName: "Monospace"
                        font.bold: true
                        font.pixelSize: settings.fontSize
                        color: index === autoCompletionList.currentIndex ? root.palette.button : root.palette.text
                        elide: Text.ElideRight
                        onClicked: {
                            insertCompletion()
                        }

                        function insertCompletion() {
                            input.text = modelData.name
                        }
                    }
                }
            }
        }
    }
}
