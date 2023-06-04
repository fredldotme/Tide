import QtQuick
import QtQuick.Controls
import Tide

Item {
    id: codeEditor

    property FileIo fileIo : null
    property ExternalProjectPicker projectPicker : null
    property DirectoryListing file : null
    property ProjectBuilder projectBuilder : null
    property OpenFilesManager openFiles : null
    property bool invalidated : true
    property bool showAutoCompletor : false

    signal saveRequested()

    function languageForLowerCaseFileName(name) {
        // Default to C++
        if (name === "")
            return SourceHighliter.CodeCpp;

        if (name === "makefile") {
            return SourceHighliter.CodeMake;
        }
        if (name === "cmakelists.txt" || name.endsWith(".cmake")) {
            return SourceHighliter.CodeMake;
        }

        if (name.endsWith(".cpp") || name.endsWith(".h") || name.endsWith(".hpp")) {
            return SourceHighliter.CodeCpp;
        }
        if (name.endsWith(".c")) {
            return SourceHighliter.CodeC;
        }
        if (name.endsWith(".qml")) {
            return SourceHighliter.CodeQML;
        }
        if (name.endsWith(".js")) {
            return SourceHighliter.CodeJs;
        }
        if (name.endsWith(".css")) {
            return SourceHighliter.CodeCSS
        }
        if (name.endsWith(".sh")) {
            return SourceHighliter.CodeBash;
        }
        if (name.endsWith(".rs")) {
            return SourceHighliter.CodeRust;
        }
        if (name.endsWith(".java")) {
            return SourceHighliter.CodeJava;
        }
        if (name.endsWith(".go")) {
            return SourceHighliter.CodeGo;
        }
        if (name.endsWith(".py")) {
            return SourceHighliter.CodePython;
        }

        return SourceHighliter.CodeCpp;
    }

    onFileChanged: {
        if (file == null)
            return

        invalidated = false
        const path = projectPicker.openBookmark(editor.file.bookmark)
        text = fileIo.readFile(file.path)
        projectPicker.closeFile(path)

        const lang = languageForLowerCaseFileName(file.name.toLowerCase())
        console.log("Language: " + lang)
        highlighter.setCurrentLanguage(lang)
        showAutoCompletor = false
        reloadAst()
    }

    function reloadAst() {
        // libclang and clang++ trip over each other regularly.
        if (projectBuilder.building)
            return;

        if (file.name.toLowerCase().endsWith(".cpp") || file.name.toLowerCase().endsWith(".h") ||
                file.name.toLowerCase().endsWith(".h")) {
            autoCompleter.setIncludePaths(projectBuilder.includePaths());
            autoCompleter.reloadAst(file.path)
        }
    }

    function invalidate () {
        invalidated = true
        showAutoCompletor = false
        text = ""
    }

    property alias text : codeField.text

    Component.onCompleted: {
        codeField.text = fileIo.readFile(file.path)
    }

    LineNumbersHelper {
        id: lineNumbersHelper
        document: codeField.textDocument
    }

    SyntaxHighlighter {
        id: highlighter
        Component.onCompleted: {
            init(codeField.textDocument, (root.palette.base !== Qt.color("#1c1c1e")))
        }
    }

    AutoCompleter {
        id: autoCompleter
    }

    Connections {
        target: root.palette
        function onChanged() {
            highlighter.init(codeField.textDocument, (root.palette.base !== Qt.color("#1c1c1e")))
        }
    }

    function refreshLineNumbers() {
        lineNumberRepeater.model = 0
        lineNumberRepeater.model = lineNumbersHelper.lineCount
    }

    Label {
        visible: codeEditor.invalidated
        text: qsTr("Select a file to edit")
        font.pixelSize: 32
        anchors.centerIn: parent
        color: root.palette.mid
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        visible: openFiles.files.length > 0

        Row {
            Column {
                id: lineNumbersColumn
                width: childrenRect.width
                Repeater {
                    id: lineNumberRepeater
                    model: lineNumbersHelper.lineCount
                    delegate: Label {
                        readonly property bool isCurrentLine :
                            lineNumbersHelper.isCurrentBlock(index, codeField.cursorPosition)
                        height: lineNumbersHelper.height(index)
                        color: isCurrentLine ? root.palette.button :
                                               root.palette.text
                        font: fixedFont
                        text: (index + 1)
                    }
                }
            }

            TextArea {
                id: codeField
                width: scrollView.width - paddingSmall - lineNumbersColumn.width
                text: ""
                onTextChanged: {
                    refreshLineNumbers()
                }
                font: fixedFont
                focus: !showAutoCompletor
                wrapMode: TextEdit.WrapAnywhere
                Component.onCompleted: imFixer.setupImEventFilter(codeField)

                Shortcut {
                    sequence: "Ctrl+Shift+S"
                    onActivated: {
                        showAutoCompletor = !showAutoCompletor
                        if (showAutoCompletor) {
                            codeEditor.saveRequested() // Implicitly calls reloadAst
                        }
                    }
                }

                Shortcut {
                    sequence: "Ctrl+S"
                    onActivated: codeEditor.saveRequested()
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.palette.shadow
                    opacity: showAutoCompletor ? 0.5 : 0.0
                    visible: opacity > 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: dialogShadow.consoleAnimation
                            easing.type: Easing.OutCubic
                        }
                    }

                    readonly property int consoleAnimation: 250

                    // Due to a Qt bug it is possible to crash the IDE by tapping a CodeEditor
                    // while the console is open and overlaid on top, apparently due to the TextField
                    // being instantiated in a different thread (how?). Catch any accidental presses
                    // in a modal way to work around this issue.
                    MouseArea {
                        anchors.fill: parent
                        onClicked:
                            (mouse) => {
                                showAutoCompletor = false
                                mouse.accepted = true
                            }
                    }
                }

                Rectangle {
                    width: Math.min(autoCompletionList.contentItem.childrenRect.width, 300)
                    height: Math.min(autoCompletionList.contentItem.childrenRect.height, 300)
                    x: codeField.cursorRectangle.x
                    y: codeField.cursorRectangle.y
                    visible: showAutoCompletor
                    color: root.palette.base
                    border.color: root.palette.text
                    border.width: 1
                    radius: root.roundedCornersRadius

                    ListView {
                        id: autoCompletionList
                        anchors.fill: parent
                        model: autoCompleter.decls
                        focus: showAutoCompletor
                        keyNavigationEnabled: true

                        function iconForKind(kind) {
                            if (kind === AutoCompleter.Function)
                                return Qt.resolvedUrl("qrc:/assets/function@2x.png");
                            else if (kind === AutoCompleter.Variable)
                                return Qt.resolvedUrl("qrc:/assets/v.square@2x.png");
                            return ""
                        }

                        function insertable(name, kind) {
                            if (kind === AutoCompleter.Function)
                                return name + "(";
                            return name;
                        }

                        delegate: TideButton {
                            icon.source: autoCompletionList.iconForKind(modelData.kind)
                            text: modelData.name
                            font.styleName: "Monospace"
                            font.bold: true
                            font.pixelSize: 24
                            color: root.palette.button
                            elide: Text.ElideRight
                            onClicked: {
                                codeField.insert(codeField.cursorPosition,
                                                 autoCompletionList.insertable(modelData.name, modelData.kind))
                                showAutoCompletor = false
                            }
                        }
                    }
                }
            }
        }
    }
}
