import QtQuick
import QtQuick.Controls
import Tide

Item {
    id: codeEditor

    property FileIo fileIo : null
    property ExternalProjectPicker projectPicker : null
    property DirectoryListing file : null
    property bool invalidated : false

    onFileChanged: {
        if (file == null)
            return

        invalidated = false
        const path = projectPicker.openBookmark(editor.file.bookmark)
        text = fileIo.readFile(file.path)
        projectPicker.closeFile(path)
    }

    function invalidate () {
        invalidated = true
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

    ScrollView {
        id: scrollView
        anchors.fill: parent

        Row {
            width: parent.width

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
                focus: true
                wrapMode: TextEdit.WrapAnywhere
                Component.onCompleted: imFixer.setupImEventFilter(codeField)
            }
        }
    }
}
