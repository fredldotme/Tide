import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Tide

Item {
    id: codeEditor

    property FileIo fileIo : null
    property ExternalProjectPicker projectPicker : null
    property DirectoryListing file : null
    property ProjectBuilder projectBuilder : null
    property OpenFilesManager openFiles : null
    property Debugger dbugger : null

    property alias codeField: codeField
    property alias preview: preview

    property bool invalidated : true
    property bool changed : false
    property bool loading : false
    property bool showAutoCompletor : false

    function scrollToLine(line) {
        let contentY = 0
        for (let currentLine = 1; currentLine < Math.min(line, lineNumbersHelper.lineCount.length); currentLine++) {
            let modelData = lineNumbersHelper.lineCount[currentLine]
            contentY += modelData.height
        }
        scrollView.ScrollBar.vertical.position =
                Math.min(contentY / scrollView.contentHeight, 1.0 - scrollView.ScrollBar.vertical.size)
    }

    onShowAutoCompletorChanged: {
        if (!showAutoCompletor) {
            codeField.forceActiveFocus()
            autoCompletorFrame.compact = true
        }
    }

    Connections {
        target: openFiles
        function onFilesChanged() {
            if (openFiles.files.length === 0) {
                invalidate()
                return
            }

            showAutoCompletor = false
            autoCompletorFrame.compact = true
            codeField.focus = true
        }
    }

    onWidthChanged: {
        refreshLineNumbers();
    }

    signal saveRequested()
    signal findRequested()
    signal buildRequested()
    signal runRequested()

    function refreshFromDisk() {
        if (invalidated)
            return
        loading = true
        codeField.text = fileIo.readFile(editor.file.path)
        loading = false
    }

    function typeStringForName(name) {
        name = name.toLowerCase()

        if (name === "")
            return ""
        if (name === "makefile")
            return "Makefile";
        if (name === "cmakelists.txt" || name.endsWith(".cmake"))
            return "CMake";
        if (name.endsWith(".pro"))
            return "QMake";
        if (name.endsWith(".txt"))
            return "Text";

        const type = languageForLowerCaseFileName(name)
        switch (type) {
        case SourceHighliter.CodeMake:
            return "Makefile"
        case SourceHighliter.CodeCpp:
            return "C++"
        case SourceHighliter.CodeC:
            return "C"
        case SourceHighliter.CodeQML:
            return "QML"
        case SourceHighliter.CodeJs:
            return "JavaScript"
        case SourceHighliter.CodeCSS:
            return "CSS"
        case SourceHighliter.CodeBash:
            return "Bash"
        case SourceHighliter.CodeRust:
            return "Rust"
        case SourceHighliter.CodeJava:
            return "Java"
        case SourceHighliter.CodeGo:
            return "Go"
        case SourceHighliter.CodePython:
            return "Python"
        }
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
        if (name.endsWith(".java")) {
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

    onInvalidatedChanged: {
        if (!invalidated)
            return;

        preview.source = ""
        text = ""
    }

    onFileChanged: {
        if (file == null) {
            preview.source = ""
            text = ""
            return
        }

        invalidated = false
        loading = true
        const bookmarkPath = projectPicker.openBookmark(editor.file.bookmark)

        codeField.visible = false
        if (root.fileIsImageFile(file.path)) {
            preview.source = "file://" + file.path
            text = ""
        } else {
            preview.source = ""
            if (fileIo.fileIsTextFile(file.path))
                text = fileIo.readFile(file.path)
            else
                text = ""
        }
        codeField.visible = true

        loading = false
        projectPicker.closeFile(bookmarkPath)

        const lang = languageForLowerCaseFileName(file.name.toLowerCase())
        console.log("Language: " + lang)

        highlighter.setCurrentLanguage(lang)
        //highlighter.setVisibleRect(codeView.width, codeView.height);
        reloadAst()
        lineNumbersHelper.refresh()
    }

    readonly property bool canUseAutocomplete : {
        if (invalidated)
            return false;

        if (!settings.autocomplete)
            return false;

        if (languageForLowerCaseFileName(file.name.toLowerCase()) === SourceHighliter.CodeC ||
                languageForLowerCaseFileName(file.name.toLowerCase()) === SourceHighliter.CodeCpp)
            return true;
        return false;
    }

    readonly property bool canUseAutoformat: {
        if (invalidated)
            return false

        if (!settings.autoformat)
            return false

        if (languageForLowerCaseFileName(file.name.toLowerCase()) === SourceHighliter.CodeC ||
                languageForLowerCaseFileName(file.name.toLowerCase()) === SourceHighliter.CodeCpp)
            return true;
        return false;
    }

    function format() {
        if (!canUseAutoformat)
            return;

        const lang = languageForLowerCaseFileName(file.name.toLowerCase())
        if (lang === SourceHighliter.CodeC || lang === SourceHighliter.CodeCpp) {
            const replacement = cppFormatter.format(codeField.text, settings.formatStyle)
            // TODO: Flash red on formatError() signal
            codeField.text = replacement
            codeEditor.changed = true
        }
    }

    function autocomplete() {
        if (!settings.autocomplete)
            return;

        if (!canUseAutocomplete) {
            return;
        }

        codeField.startCursorPosition = codeField.cursorPosition
        codeEditor.saveRequested() // Implicitly calls reloadAst
        showAutoCompletor = !showAutoCompletor
        if (showAutoCompletor && autoCompletorFrame.compact) {
            codeField.forceActiveFocus()
        }
    }

    function reloadAst() {
        // Old State: libclang and clang++ trip over each other regularly.
        // New State: iOS enablement in LLVM has ManagedStatic as thread-local, should not happen as much anymore
        //if (projectBuilder.building)
        //    return;

        if (file.name.toLowerCase().endsWith(".cpp") || file.name.toLowerCase().endsWith(".c") ||
                file.name.toLowerCase().endsWith(".h") || file.name.toLowerCase().endsWith(".hpp") ||
                file.name.toLowerCase().endsWith(".cc") || file.name.toLowerCase().endsWith(".cxx")) {
            autoCompleter.setIncludePaths(projectBuilder.includePaths());
            autoCompleter.reloadAst([file.path], "", AutoCompleter.Unspecified, /*codeField.currentLine*/ 0, /*codeField.currentColumn*/ 0)
        }
    }

    function invalidate () {
        invalidated = true
        text = ""
        changed = false
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


    property var autoCompleter : AutoCompleter {
        pluginsManager: pluginManager
        onDeclsChanged: {
            console.log("Autocompleter decls changed");
        }
    }

    CppFormatter {
        id: cppFormatter
    }

    Connections {
        target: root.palette
        function onChanged() {
            highlighter.init(codeField.textDocument,
                             (root.palette.base !== Qt.color("#1c1c1e")))
        }
    }

    function refreshLineNumbers() {
        if (invalidated)
            return;
        lineNumbersHelper.delayedRefresh()
    }

    Rectangle {
        id: mainEditorContainer
        anchors.fill: parent
        radius: root.roundedCornersRadiusMedium
        border.color: root.borderColor
        border.width: 1
        color: root.palette.base
        clip: true

        Image {
            id: preview
            anchors.centerIn: parent
            width: Math.min(parent.width, implicitWidth)
            height: Math.min(parent.height, implicitHeight)
            visible: opacity > 0.0
            enabled: opacity > 0.0
            opacity: source !== "" ? 1.0 : 0.0
            fillMode: Image.PreserveAspectFit
            Behavior on opacity {
                NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: paddingMedium
            enabled: opacity > 0.0
            visible: opacity > 0.0

            opacity: invalidated ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                width: parent.width
                spacing: 0

                Image {
                    Layout.alignment: Qt.AlignCenter
                    source: Qt.resolvedUrl("qrc:/assets/TideNaked@2x.png")
                    Layout.preferredWidth: Math.min(128, parent.width)
                    Layout.preferredHeight: width
                }
                Label {
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: parent.width
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    text: qsTr("Tide IDE")
                    font.pixelSize: 26
                    color: root.palette.text
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ColumnLayout {
                width: parent.width
                spacing: 0
                Button {
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: parent.width
                    flat: true
                    text: qsTr("Examples")
                    spacing: 8
                    icon.source: Qt.resolvedUrl("qrc:/assets/link@2x.png")
                    font.pixelSize: 20
                    onClicked: {
                        git.clone("https://github.com/fredldotme/TideExamples", "TideExamples");
                    }
                }
                Button {
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: parent.width
                    flat: true
                    text: qsTr("Settings")
                    spacing: 8
                    icon.source: Qt.resolvedUrl("qrc:/assets/gearshape.fill@2x.png")
                    font.pixelSize: 20
                    onClicked: {
                        root.toggleSettingsDialog()
                    }
                }
                Button {
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: parent.width
                    flat: true
                    text: qsTr("Help")
                    spacing: 8
                    icon.source: Qt.resolvedUrl("qrc:/assets/questionmark.circle.fill@2x.png")
                    font.pixelSize: 20
                    onClicked: {
                        root.toggleHelpDialog()
                    }
                }
            }
        }

        Connections {
            target: settings
            function onWrapEditorChanged() {
                lineNumbersHelper.refresh()
            }
        }

        Connections {
            target: root
            function onReloadFilestructure() {
                // Reload previews
                const toReload = preview.source
                preview.source = ""
                preview.source = toReload

                // Reset "Unsaved" state
                changed = false
            }
        }

        Column {
            id: mainEditorColumn
            anchors.fill: parent
            clip: true
            visible: !root.fileIsImageFile(file.path)
            opacity: invalidated ? 0.0 : 1.0
            Behavior on opacity {
                NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
            }

            ScrollView {
                id: scrollView
                contentWidth: settings.wrapEditor ?
                                  -1 :
                                  codeField.implicitWidth + paddingSmall + lineNumbersColumn.width
                contentHeight: codeField.implicitHeight
                visible: !codeEditor.invalidated
                width: parent.width
                height: parent.height - detailArea.height
                clip: true

                ScrollBar.horizontal: TideScrollBar {
                    parent: scrollView
                    size: scrollView.width / codeView.width
                    leftPadding: 0
                    rightPadding: 0
                    orientation: Qt.Horizontal
                    visible: !settings.wrapEditor
                }
                ScrollBar.vertical: TideScrollBar {
                    parent: scrollView
                    size: scrollView.height / codeView.height
                    bottomPadding: 0
                }

                Rectangle {
                    id: currentLineIndicator
                    width: Math.max(codeView.implicitWidth, mainEditorColumn.width)
                    color: codeField.selectionColor
                    visible: codeField.focus && !codeField.readOnly
                    height: lineNumbersHelper.lineCount[codeField.currentLine - 1] !== undefined ?
                                lineNumbersHelper.lineCount[codeField.currentLine - 1].height : 0
                    x: codeView.x
                    y: contentY()
                    opacity: 0.15

                    function contentY() {
                        let contentY = 0
                        for (let currentLine = 0; currentLine < Math.min(codeField.currentLine - 1, lineNumbersHelper.lineCount.length); currentLine++) {
                            let modelData = lineNumbersHelper.lineCount[currentLine]
                            contentY += modelData.height
                        }
                        return contentY
                    }
                }

                Rectangle {
                    id: currentLineOfExecutionIndicator
                    width: Math.max(codeView.implicitWidth, codeField.width)
                    color: "orange"
                    visible: dbugger.currentLineOfExecution !== "" &&
                             dbugger.currentLineOfExecution.indexOf(file.path) === 0
                    height: lineNumbersHelper.lineCount[pos()] !== undefined ?
                                lineNumbersHelper.lineCount[pos()].height : 0
                    x: codeView.x
                    y: contentY()
                    opacity: 0.3

                    function pos() {
                        let line = dbugger.currentLineOfExecution.split(':')
                        if (line.length == 0)
                            return 0
                        return parseInt(line[line.length - 1]) - 1
                    }

                    function contentY() {
                        let contentY = 0
                        for (let currentLine = 0; currentLine < Math.min(pos(), lineNumbersHelper.lineCount.length); currentLine++) {
                            let modelData = lineNumbersHelper.lineCount[currentLine]
                            contentY += modelData.height
                        }
                        return contentY
                    }
                }

                RowLayout {
                    id: codeView
                    anchors.fill: parent
                    anchors.leftMargin: roundedCornersRadius
                    spacing: paddingSmall

                    Column {
                        id: lineNumbersColumn
                        Layout.fillHeight: true
                        Layout.preferredWidth: childrenRect.width

                        Repeater {
                            id: lineNumberRepeater
                            model: lineNumbersHelper.lineCount
                            delegate: Label {
                                id: lineLabel

                                readonly property bool isCurrentLine :
                                    lineNumbersHelper.isCurrentBlock(index, codeField.cursorPosition)
                                property bool isBreakpoint :
                                    dbugger.hasBreakpoint(file.path + ":" + (index + 1))

                                Connections {
                                    target: dbugger
                                    function onBreakpointsChanged() {
                                        lineLabel.isBreakpoint = dbugger.hasBreakpoint(file.path + ":" + (index + 1))
                                    }
                                }

                                color: isCurrentLine ?
                                           root.palette.button :
                                           root.palette.text

                                background: Rectangle {
                                    radius: height / 2
                                    readonly property bool visiblity : lineLabel.isBreakpoint
                                    opacity: visibility ? 1.0 : 0.0
                                    visible: opacity > 0.0
                                    color: lineLabel.isBreakpoint ? "red" : "transparent"
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                }

                                height: modelData.height
                                font: fixedFont
                                text: (index + 1)
                                anchors.right: parent.right

                                MouseArea {
                                    acceptedButtons: Qt.AllButtons
                                    anchors.fill: parent
                                    onClicked: {
                                        const lang = languageForLowerCaseFileName(codeEditor.file.name.toLowerCase())
                                        if (lang !== SourceHighliter.CodeC && lang !== SourceHighliter.CodeCpp) {
                                            return;
                                        }

                                        const breakpoint = file.path + ":" + (index + 1);
                                        console.log("Setting breakpoint at " + breakpoint);

                                        if (dbugger.hasBreakpoint(breakpoint)) {
                                            dbugger.removeBreakpoint(breakpoint)
                                        } else {
                                            dbugger.addBreakpoint(breakpoint)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    TextEdit {
                        id: codeField
                        Layout.fillHeight: true
                        Layout.fillWidth: settings.wrapEditor

                        text: ""
                        onEditingFinished: {
                            if (codeEditor.loading)
                                return;
                            codeEditor.changed = true
                        }
                        focus: true
                        selectionColor: "dodgerblue"
                        font: fixedFont
                        wrapMode: settings.wrapEditor ? TextEdit.WrapAnywhere : TextEdit.NoWrap
                        Component.onCompleted: {
                            //uiIntegration.hookUpNativeView(codeField)
                            imFixer.setupImEventFilter(codeField)
                        }
                        // background: Item { }
                        cursorDelegate: Component {
                            Rectangle {
                                id: cursor
                                color: codeField.selectionColor
                                width: 3
                                height: codeField.font.pixelSize
                                Timer {
                                    id: cursorBlinkTimer
                                    repeat: true
                                    running: settings.blinkingCursor
                                    interval: 500
                                    onTriggered: {
                                        cursor.visible = !cursor.visible
                                    }
                                }
                                Connections {
                                    target: settings
                                    function onBlinkingCursorChanged() {
                                        cursor.visible = true
                                    }
                                }
                            }
                        }

                        FontMetrics {
                            id: fontMetrics
                            font: codeField.font
                        }

                        tabStopDistance: settings.tabWidth * fontMetrics.maximumCharacterWidth
                        onImplicitHeightChanged: lineNumbersHelper.refresh()

                        Keys.onTabPressed:
                            (event) => {
                                event.accepted = false;

                                if (settings.spacesForTab === 0) {
                                    codeField.insert(codeField.cursorPosition, "\t")
                                    event.accepted = true
                                    return
                                }

                                let insertable = ""
                                for (let i = 0; i < settings.spacesForTab; i++) {
                                    insertable += " "
                                }
                                codeField.insert(codeField.cursorPosition, insertable)
                                event.accepted = true
                            }
                        Keys.onUpPressed:
                            (event) => {
                                if (showAutoCompletor) {
                                    autoCompletionList.currentIndex = Math.max(autoCompletionList.currentIndex - 1, 0)
                                    event.accepted = true
                                    return
                                }

                                event.accepted = false
                            }
                        Keys.onDownPressed:
                            (event) => {
                                if (showAutoCompletor) {
                                    autoCompletionList.currentIndex = Math.min(autoCompletionList.currentIndex + 1, autoCompletionList.model.length - 1)
                                    event.accepted = true
                                    return
                                }

                                event.accepted = false
                            }
                        Keys.onReturnPressed:
                            (event) => {
                                event.accepted = false

                                if (showAutoCompletor) {
                                    const insertable = autoCompletionList.insertable(
                                        autoCompletionList.model[autoCompletionList.currentIndex].name,
                                        autoCompletionList.model[autoCompletionList.currentIndex].kind)
                                    codeField.remove(codeField.startCursorPosition, codeField.cursorPosition)
                                    codeField.insert(codeField.startCursorPosition, insertable)
                                    codeEditor.showAutoCompletor = false
                                    event.accepted = true
                                    return
                                }

                                if (settings.autoindent) {
                                    // Find the previous newline
                                    let previousNewlinePosition = 0
                                    for (let i = codeField.cursorPosition - 1; i >= 0; i--) {
                                        if (codeField.text[i] === '\n') {
                                            previousNewlinePosition = i;
                                            break;
                                        }
                                    }

                                    if (previousNewlinePosition !== 0) {
                                        // Find spaces/tabs from there on out until the next character
                                        let indentation = "";
                                        for (let j = previousNewlinePosition + 1; j < codeField.text.length; j++) {
                                            if (codeField.text[j] === ' ' || codeField.text[j] === '\t') {
                                                indentation += codeField.text[j];
                                            } else {
                                                break;
                                            }
                                        }

                                        if (indentation !== "") {
                                            codeField.insert(codeField.cursorPosition, "\n" + indentation)
                                            event.accepted = true
                                        }
                                    }
                                }
                            }

                        readonly property int currentLine: lineNumbersHelper.currentLine(codeField.cursorPosition) + 1
                        readonly property int currentColumn: lineNumbersHelper.currentColumn(codeField.cursorPosition) + 1

                        property int startCursorPosition : 0
                        onCursorPositionChanged: {
                            if (cursorPosition < startCursorPosition)
                                codeEditor.showAutoCompletor = false

                            if (!settings.wrapEditor) {
                                if (cursorRectangle.x > scrollView.width ||
                                        cursorRectangle.x < scrollView.contentItem.contentX) {
                                    scrollView.contentItem.contentX = (cursorRectangle.x - paddingSmall)
                                }
                            }

                            if (cursorRectangle.y < scrollView.contentItem.contentY) {
                                scrollView.contentItem.contentY = cursorRectangle.y
                            } else if (cursorRectangle.y >= scrollView.contentItem.contentY + scrollView.height) {
                                scrollView.contentItem.contentY = cursorRectangle.y - scrollView.height + currentLineIndicator.height - 1
                            }
                        }

                        readonly property string currentBlock : {
                            if (!showAutoCompletor)
                                return ""

                            if (codeField.startCursorPosition == codeField.cursorPosition)
                                return ""

                            let start = codeField.startCursorPosition
                            let end = 0

                            const matcher = RegExp(/[a-zA-Z_\-0-9]/, 'u')
                            for (let needle = start; needle <= codeField.cursorPosition; needle++) {
                                if (matcher.test(codeField.text[needle])) {
                                    end = needle;
                                } else {
                                    break;
                                }
                            }

                            let ret = codeField.text.substring(start, end)
                            ret = ret.trim()

                            console.log("currentBlock: " + ret)
                            return ret;
                        }

                        MouseArea {
                            anchors.fill: parent
                            visible: enabled
                            enabled: showAutoCompletor
                            onClicked:
                                (event) => {
                                    codeEditor.showAutoCompletor = false
                                    event.accepted = true
                                }
                        }

                        Rectangle {
                            id: autoCompletorFrame
                            readonly property bool visibility : showAutoCompletor
                            opacity: visibility ? 1.0 : 0.0
                            visible: opacity > 0.0
                            scale: visibility ? 1.0 : 0.8
                            color: root.palette.base
                            border.color: root.palette.shadow
                            border.width: 1
                            radius: roundedCornersRadiusSmall
                            clip: true

                            Behavior on width {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutExpo
                                }
                            }
                            Behavior on height {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutExpo
                                }
                            }
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
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutExpo
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutExpo
                                }
                            }

                            states: [
                                State {
                                    name: "compact"
                                    PropertyChanges {
                                        target: autoCompletorFrame
                                        x: localCoord.x - framePaddingX()
                                        y: localCoord.y - framePaddingY()
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

                            property bool compact : true
                            state: compact && root.landscapeMode ? "compact" : "expanded"

                            readonly property int maxWidth : state === "compact" ? 500 : mainView.dialogWidth
                            readonly property int maxHeight : state === "compact" ? 300 : mainView.dialogHeight

                            function framePaddingX() {
                                return (codeField.cursorRectangle.x + width > codeEditor.width) ?
                                            width + codeField.font.pixelSize : 0
                            }

                            function framePaddingY () {
                                return (codeField.cursorRectangle.y + height > codeEditor.height) ?
                                            height : -codeField.font.pixelSize
                            }

                            property var localCoord : codeField.cursorRectangle
                            width: maxWidth
                            height: Math.max(autoCompletorButtonArea.height, Math.min(autoCompletorContent.height, maxHeight))
                            x: localCoord.x - framePaddingX()
                            y: localCoord.y - framePaddingY()

                            parent: state === "compact" ? codeField : mainContainer

                            Component.onCompleted: {
                                imFixer.setupImEventFilter(autoCompletionInput)
                                autoCompletionInputFocusScope.forceActiveFocus()
                            }

                            Column {
                                id: autoCompletorContent
                                width: parent.width

                                FocusScope {
                                    id: autoCompletionInputFocusScope
                                    width: autoCompletionInput.width
                                    height: autoCompletionInput.height
                                    focus: true
                                    TextField {
                                        id: autoCompletionInput
                                        width: autoCompletorFrame.width - autoCompletorButtonArea.width
                                        height: autoCompletorFrame.state === "compact" ? 0 : implicitHeight
                                        focus: showAutoCompletor && autoCompletorFrame.state !== "compact"
                                        topInset: 0
                                        leftInset: 0
                                        rightInset: 0
                                        bottomInset: 0

                                        onAccepted: {
                                            const insertable = autoCompletionList.insertable(
                                                                 autoCompletionList.model[autoCompletionList.currentIndex].name,
                                                                 autoCompletionList.model[autoCompletionList.currentIndex].kind)
                                            codeField.insert(codeField.startCursorPosition, insertable)
                                            codeField.cursorPosition = codeField.startCursorPosition + insertable.length
                                            text = ""
                                            codeEditor.showAutoCompletor = false
                                        }

                                        Keys.onUpPressed: {
                                            autoCompletionList.currentIndex =
                                                    Math.abs(autoCompletionList.currentIndex - 1) % autoCompletionList.model.length
                                        }
                                        Keys.onDownPressed: {
                                            autoCompletionList.currentIndex =
                                                    Math.abs(autoCompletionList.currentIndex + 1) % autoCompletionList.model.length
                                        }
                                    }
                                }

                                Label {
                                    text: qsTr("Nothing found")
                                    font.pixelSize: 24
                                    color: root.palette.text
                                    horizontalAlignment: Qt.AlignHCenter
                                    verticalAlignment: Qt.AlignVCenter
                                    width: autoCompletorFrame.width
                                    height: 200
                                    visible: autoCompletionList.model.length === 0
                                }

                                ScrollView {
                                    id: autoCompletionScrollView
                                    width: autoCompletionList.width
                                    height: autoCompletionList.height
                                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                                    ListView {
                                        id: autoCompletionList
                                        model: autoCompletorFrame.state !== "compact" && autoCompletionInput.text !== "" ?
                                                   autoCompleter.filteredDecls(autoCompletionInput.text) :
                                                   autoCompletorFrame.state === "compact" && codeField.currentBlock !== "" ?
                                                       autoCompleter.filteredDecls(codeField.currentBlock) :
                                                       autoCompleter.decls
                                        contentWidth: contentItem.childrenRect.width
                                        contentHeight: contentItem.childrenRect.height
                                        width: Math.min(contentWidth, autoCompletorFrame.maxWidth)
                                        height: Math.min(contentHeight, autoCompletorFrame.maxHeight - autoCompletionInput.height)
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

                                        function insertable(name, kind) {
                                            if (kind === AutoCompleter.Function)
                                                return name + "(";
                                            return name;
                                        }

                                        delegate: TidePrefixedButton {
                                            width: autoCompletorFrame.width
                                            icon.source: autoCompletionList.iconForKind(modelData.kind)
                                            prefix: modelData.name
                                            text: modelData.prefix
                                            detail: modelData.detail !== "" ? qsTr("inside %1").arg(modelData.detail) :
                                                                              qsTr("in %1").arg(file.name)
                                            font.styleName: "Monospace"
                                            font.bold: true
                                            font.pixelSize: 20
                                            color: index === autoCompletionList.currentIndex ? root.palette.button : root.palette.dark
                                            elide: Text.ElideRight
                                            onClicked: {
                                                insertCompletion()
                                            }
                                            function insertCompletion() {
                                                showAutoCompletor = false
                                                codeField.insert(codeField.cursorPosition,
                                                                 autoCompletionList.insertable(modelData.name, modelData.kind))
                                            }
                                        }
                                    }
                                }
                            }

                            Row {
                                id: autoCompletorButtonArea
                                anchors.top: parent.top
                                anchors.right: parent.right

                                Button {
                                    icon.source: Qt.resolvedUrl("qrc:/assets/magnifyingglass.circle.fill@2x.png")
                                    icon.width: 24
                                    icon.height: 24
                                    flat: true
                                    background: Rectangle {
                                        color: root.palette.base
                                        border.color: root.palette.shadow
                                        border.width: 1
                                    }
                                    onClicked: {
                                        autoCompletorFrame.compact = !autoCompletorFrame.compact
                                        if (autoCompletorFrame.state !== "compact")
                                            autoCompletionInput.forceActiveFocus()
                                    }
                                }
                                Button {
                                    icon.source: Qt.resolvedUrl("qrc:/assets/xmark.circle.fill@2x.png")
                                    icon.width: 24
                                    icon.height: 24
                                    flat: true
                                    background: Rectangle {
                                        color: root.palette.base
                                        border.color: root.palette.shadow
                                        border.width: 1
                                    }
                                    onClicked: {
                                        codeEditor.showAutoCompletor = false
                                    }
                                }
                            }
                        }

                        MultiEffect {
                            source: autoCompletorFrame
                            anchors.fill: autoCompletorFrame
                            shadowEnabled: true
                            shadowBlur: 0.3
                            visible: autoCompletorFrame.visible
                            opacity: autoCompletorFrame.opacity
                            scale: autoCompletorFrame.scale
                            parent: autoCompletorFrame.parent
                        }
                    }
                }
            }

            RowLayout {
                id: detailArea
                visible: !codeEditor.invalidated
                height: implicitHeight

                Label {
                    Layout.leftMargin: roundedCornersRadiusMedium
                    text: qsTr("Line %1").arg(codeField.currentLine)
                    font.pixelSize: 12
                    color: root.palette.text
                }

                Rectangle {
                    Layout.preferredHeight: parent.height
                    Layout.preferredWidth: 1
                    color: root.palette.text
                }

                Label {
                    text: qsTr("Column %1").arg(codeField.currentColumn)
                    font.pixelSize: 12
                    color: root.palette.text
                }

                Rectangle {
                    Layout.preferredHeight: parent.height
                    Layout.preferredWidth: 1
                    color: root.palette.text
                }

                Label {
                    text: typeStringForName(file.name)
                    visible: text !== ""
                    font.pixelSize: 12
                    color: root.palette.text
                }
            }
        }
    }

    /*MultiEffect {
        source: mainEditorContainer
        anchors.fill: mainEditorContainer
        paddingRect: Qt.rect(0, 0, mainEditorContainer.width, mainEditorContainer.height)
        shadowEnabled: true
        shadowBlur: 1.0
        shadowOpacity: defaultRectangleShadow
    }*/

    Rectangle {
        id: codeFieldCurtain
        anchors.fill: parent
        opacity: 0.5
        color: root.palette.shadow
        visible: autoCompletorFrame.state !== "compact" && showAutoCompletor
        MouseArea {
            anchors.fill: parent
            onClicked: {
                codeEditor.showAutoCompletor = false
            }
        }
    }
}

