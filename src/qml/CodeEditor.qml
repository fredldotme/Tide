import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Tide

Rectangle {
    id: codeEditor
    radius: root.roundedCornersRadiusMedium
    color: root.palette.base

    property FileIo fileIo : null
    property ExternalProjectPicker projectPicker : null
    property DirectoryListing file : null
    property ProjectBuilder projectBuilder : null
    property OpenFilesManager openFiles : null

    property alias codeField: codeField

    property bool invalidated : true
    property bool showAutoCompletor : false
    property bool changed : false

    onShowAutoCompletorChanged: {
        codeField.startCursorPosition = codeField.cursorPosition
    }

    Connections {
        target: openFiles
        function onFilesChanged() {
            if (openFiles.files.length === 0) {
                invalidate()
            }
        }
    }

    signal saveRequested()
    signal findRequested()
    signal buildRequested()
    signal runRequested()

    function refreshFromDisk() {
        if (invalidated)
            return;
        codeField.text = fileIo.readFile(editor.file.path)
        changed = false
    }

    function languageForLowerCaseFileName(name) {
        // Default to Something like makefile until we have Markdown support
        if (name === "")
            return SourceHighliter.CodeMake;

        if (name === "makefile") {
            return SourceHighliter.CodeMake;
        }
        if (name === "cmakelists.txt" || name.endsWith(".cmake")) {
            return SourceHighliter.CodeMake;
        }

        if (name.endsWith(".cpp") || name.endsWith(".h") || name.endsWith(".hpp") || name.endsWith(".cc")) {
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

        return SourceHighliter.CodeMake;
    }

    onFileChanged: {
        if (file == null)
            return

        invalidated = false
        const path = projectPicker.openBookmark(editor.file.bookmark)
        text = fileIo.readFile(file.path)
        changed = false
        projectPicker.closeFile(path)

        const lang = languageForLowerCaseFileName(file.name.toLowerCase())
        console.log("Language: " + lang)
        highlighter.setCurrentLanguage(lang)
        showAutoCompletor = false
        reloadAst()
    }

    readonly property bool canUseAutocomplete : {
        if (languageForLowerCaseFileName(file.name.toLowerCase()) === SourceHighliter.CodeC ||
                languageForLowerCaseFileName(file.name.toLowerCase()) === SourceHighliter.CodeCpp)
            return true;
        return false;
    }

    function format() {
        if (!settings.autoformat)
            return;

        const lang = languageForLowerCaseFileName(file.name.toLowerCase())
        if (lang === SourceHighliter.CodeC || lang === SourceHighliter.CodeCpp) {
            const replacement = cppFormatter.format(codeField.text, settings.formatStyle)
            // TODO: Flash red on formatError() signal
            codeField.text = replacement
            codeEditor.changed = true
        }
    }

    function reloadAst() {
        // libclang and clang++ trip over each other regularly.
        if (projectBuilder.building)
            return;

        if (file.name.toLowerCase().endsWith(".cpp") || file.name.toLowerCase().endsWith(".c") ||
                file.name.toLowerCase().endsWith(".h") || file.name.toLowerCase().endsWith(".hpp") ||
                file.name.toLowerCase().endsWith(".cc") || file.name.toLowerCase().endsWith(".cxx")) {
            autoCompleter.setIncludePaths(projectBuilder.includePaths());
            autoCompleter.reloadAst(file.path, codeField.currentBlock())
        }
    }

    function invalidate () {
        invalidated = true
        showAutoCompletor = false
        text = ""
    }

    property alias text : codeField.text

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

    CppFormatter {
        id: cppFormatter
    }

    Connections {
        target: root.palette
        function onChanged() {
            highlighter.init(codeField.textDocument, (root.palette.base !== Qt.color("#1c1c1e")))
        }
    }

    function refreshLineNumbers() {
        lineNumberRepeater.model = 0
        if (invalidated)
            return;

        lineNumberRepeater.model = lineNumbersHelper.lineCount
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: codeEditor.invalidated
        spacing: paddingMedium
        Image {
            Layout.alignment: Qt.AlignCenter
            source: Qt.resolvedUrl("qrc:/assets/TideNaked@2x.png")
            Layout.preferredWidth: Math.min(128, parent.width)
            Layout.preferredHeight: width
        }
        Label {
            Layout.alignment: Qt.AlignCenter
            text: qsTr("Select a project or file to edit")
            font.pixelSize: 32
            color: root.palette.midlight
        }
    }

    ScrollView {
        id: scrollView
        contentWidth: -1
        anchors.fill: parent
        anchors.margins: roundedCornersRadius
        visible: !codeEditor.invalidated

        Row {
            id: codeView
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
                    codeEditor.changed = true
                }
                font: fixedFont
                focus: !showAutoCompletor
                wrapMode: TextEdit.WrapAnywhere
                Component.onCompleted: imFixer.setupImEventFilter(codeField)
                property int startCursorPosition : 0
                onCursorPositionChanged: {
                    if (codeField.cursorPosition < codeField.startCursorPosition)
                        showAutoCompletor = false
                }

                function currentBlock() {
                    let start = 0
                    let end = 0
                    const anchor = codeField.startCursorPosition
                    console.debug("Centering at " + anchor)

                    for (let needle = anchor; needle > 0; needle--) {
                        if (codeField.text[needle] === ' ' || codeField.text[needle] === '\r' || codeField.text[needle] === '\n') {
                            start = needle + 1;
                            break;
                        }
                    }
                    for (let needle = anchor; needle < codeField.text.length; needle++) {
                        if (codeField.text[needle] === ' ' || codeField.text[needle] === '\r' || codeField.text[needle] === '\n') {
                            end = needle - 1;
                            break;
                        }
                    }

                    return codeField.text.substring(start, end)
                }

                readonly property string filterString: autoCompletionInput.text

                Shortcut {
                    sequence: "Ctrl+Shift+S"
                    onActivated: {
                        if (!settings.autocomplete)
                            return;

                        if (!canUseAutocomplete) {
                            return;
                        }

                        showAutoCompletor = !showAutoCompletor
                        if (showAutoCompletor) {
                            codeEditor.saveRequested() // Implicitly calls reloadAst
                        }
                    }
                }

                Shortcut {
                    sequence: "Ctrl+B"
                    onActivated: codeEditor.buildRequested()
                }

                Shortcut {
                    sequence: "Ctrl+R"
                    onActivated: codeEditor.runRequested()
                }

                Shortcut {
                    sequence: "Ctrl+S"
                    onActivated: codeEditor.saveRequested()
                }

                Shortcut {
                    sequence: "Ctrl+F"
                    onActivated: codeEditor.findRequested()
                }

                Shortcut {
                    sequence: "Ctrl+Shift+F"
                    onActivated: {
                        codeEditor.format()
                    }
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
                    id: autoCompletorFrame
                    width: Math.min(autoCompletionList.contentItem.childrenRect.width, 300)
                    height: Math.min(autoCompletionList.contentItem.childrenRect.height, 300) + autoCompletionInput.height
                    x: codeField.cursorRectangle.x
                    y: codeField.cursorRectangle.y
                    visible: showAutoCompletor
                    color: root.palette.base
                    clip: true
                    border.color: root.palette.text
                    border.width: 1
                    radius: root.roundedCornersRadiusSmall

                    Column {
                        anchors.fill: parent

                        TextField {
                            id: autoCompletionInput
                            width: autoCompletionList.width
                            focus: showAutoCompletor
                            onFocusChanged: {
                                if (focus)
                                    text = ""
                            }

                            onAccepted: {
                                codeField.insert(codeField.startCursorPosition,
                                                 autoCompletionList.insertable(
                                                     autoCompletionList.model[autoCompletionList.currentIndex].name,
                                                     autoCompletionList.model[autoCompletionList.currentIndex].kind))
                                showAutoCompletor = false
                                text = ""
                            }
                        }

                        ListView {
                            id: autoCompletionList
                            model: (codeField.filterString === "") ?
                                       autoCompleter.decls :
                                       autoCompleter.filteredDecls(codeField.filterString)
                            width: Math.min(autoCompletionList.contentItem.childrenRect.width, 300)
                            height: Math.min(autoCompletionList.contentItem.childrenRect.height, 300)

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
                                color: index === autoCompletionList.currentIndex ? root.palette.button : root.palette.dark
                                elide: Text.ElideRight
                                onClicked: {
                                    insertCompletion()
                                    showAutoCompletor = false
                                }
                                function insertCompletion() {
                                    codeField.insert(codeField.cursorPosition,
                                                     autoCompletionList.insertable(modelData.name, modelData.kind))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

