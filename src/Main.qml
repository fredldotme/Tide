import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Tide

ApplicationWindow {
    id: root
    width: 640
    height: 480
    visible: true
    title: qsTr("Tide")

    readonly property int paddingSmall: 8
    readonly property int roundedCornersRadius: 16
    readonly property int sideBarWidth: 300

    property bool showLeftSideBar: true

    property string consoleOutput: ""
    property bool compiling: false

    function saveFile(file) {
        const path = projectPicker.openBookmark(file.bookmark)
        fileIo.writeFile(file.path, editor.text)
        projectPicker.closeFile(path);
    }

    function saveCurrentFile() {
        saveFile(editor.file)
    }

    onActiveChanged: {
        if (active) {
            cleanObsoleteProjects()
        }
    }

    onWidthChanged: {
        editor.refreshLineNumbers()
        if (width < height)
            showLeftSideBar = false
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            spacing: paddingSmall * 2

            ToolButton {
                icon.source: Qt.resolvedUrl("qrc:/assets/sidebar.left@2x.png")
                icon.color: root.palette.button
                onClicked: showLeftSideBar = !showLeftSideBar
                visible: bookmarkDb.bookmarks.length > 0
            }

            ToolButton {
                icon.source: Qt.resolvedUrl("qrc:/assets/square.and.arrow.down.on.square@2x.png")
                icon.color: root.palette.button
                onClicked: projectPicker.startImport()
            }

            Label {
                Layout.fillWidth: true
                color: root.palette.button
                text: compiling ? qsTr("Compiling... get your swords!") :
                                  qsTr("Tide")
                elide: Text.ElideRight
                horizontalAlignment: Label.AlignHCenter
                verticalAlignment: Label.AlignVCenter
            }

            ToolButton {
                visible: openFiles.files.length > 0
                icon.source: Qt.resolvedUrl("qrc:/assets/hammer.fill@2x.png")
                icon.color: root.palette.button
                onClicked: {
                    saveCurrentFile()
                    compiling = true
                    iosSystem.runBuildCommand("clang++" +
                                              " --sysroot=" + sysroot +
                                              " -o ~/Documents/a.out \"" + editor.file.path + "\"")
                }
            }
            ToolButton {
                visible: openFiles.files.length > 0
                icon.source: Qt.resolvedUrl("qrc:/assets/play.fill@2x.png")
                icon.color: root.palette.button

                WasmRunner {
                    id: wasmRunner
                    onPrintfReceived:
                        (str) => {
                            console.log("PRINTF: " + str)
                        }
                    onErrorOccured:
                        (str) => {
                            consoleOutput += str
                            consoleView.show()
                        }
                }

                onClicked: {
                    if (!editor)
                        return;

                    consoleView.show()
                    wasmRunner.kill();
                    wasmRunner.run("a.out", [])
                }
            }
            ToolButton {
                visible: openFiles.files.length > 0
                icon.source: Qt.resolvedUrl("qrc:/assets/terminal.fill@2x.png")
                icon.color: root.palette.button

                onClicked: {
                    if (consoleView.visible)
                        consoleView.hide()
                    else
                        consoleView.show()
                }
            }
        }
    }

    ExternalProjectPicker {
        id: projectPicker
    }

    BookmarkDb {
        id: bookmarkDb
    }

    FileIo {
        id: fileIo
    }

    OpenFilesManager {
        id: openFiles
        onFilesChanged: {
            if (files.length === 0) {
                openFilesArea.height = 0
            } else {
                openFilesArea.height = openFilesArea.usualHeight
            }
        }
    }

    SysrootManager {
        id: sysrootManager
    }

    Connections {
        target: iosSystem
        function onCommandEnded(ret) {
            compiling = false

            console.log("Command retuned: " + ret);
            if (ret !== 0) {
                warningSign.flashWarning(qsTr("Build failed!"))
            } else {
                warningSign.flashSuccess(qsTr("Build successful!"))
            }
        }
    }

    Console {
        id: consoleHandler
        onContentRead:
            (line, stdout) => {
                console.log("Output: " + line);
                consoleOutput += line
            }
    }

    Component.onCompleted: {
        projectPicker.documentSelected.connect(directorySelected);
        iosSystem.stdioCreated.connect(function(spec) {
            consoleHandler.feedProgramSpec(spec)
        });
        iosSystem.stdioWritersPrepared.connect(function(spec) {
            wasmRunner.prepareStdio(spec)
        });
        iosSystem.setupStdIo()

        sysrootManager.installBundledSysroot();

        if (bookmarkDb.bookmarks.count === 0)
            projectPicker.startImport();
    }

    function cleanObsoleteProjects() {
        for (const bookmark in bookmarkDb.bookmarks) {
            if (!projectPicker.openBookmark(bookmark))
                bookmarkDb.removeBookmark(bookmark);
            projectPicker.closeFile(bookmark)
        }
    }

    function directorySelected(bookmark) {
        bookmarkDb.importProject(bookmark)
    }

    function openEditor(modelData) {
        openFiles.push(modelData)
        editor.file = modelData
    }

    Text {
        anchors.centerIn: parent
        width: parent.width
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        font.pixelSize: 32
        color: root.palette.text
        text: qsTr("Import a project and start developing!")
        visible: bookmarkDb.bookmarks.length === 0
        horizontalAlignment: Text.AlignHCenter
    }

    Row {
        id: mainView
        anchors.fill: parent
        spacing: 1
        visible: bookmarkDb.bookmarks.length > 0
        onVisibleChanged: mainView.forceLayout()

        Rectangle {
            id: leftSideBar
            width: showLeftSideBar ? sideBarWidth : 0
            height: parent.height
            color: root.palette.base
            clip: true

            Behavior on width {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic; }
            }

            onWidthChanged: {
                if (width > 0 && width < sideBarWidth)
                    return;

                editor.refreshLineNumbers()
            }

            Item {
                anchors.fill: parent
                anchors.margins: paddingSmall * 2

                Column {
                    width: parent.width
                    height: parent.height

                    Column {
                        width: parent.width
                        height: openFilesArea.height == 0 ?
                                    parent.height :
                                    (parent.height - fileSeperator.height) / 2

                        Behavior on height {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        Label {
                            id: projectsTitle
                            text: qsTr("Projects & files:")
                            font.pixelSize: 16
                            color: root.palette.text
                            y: paddingSmall
                        }

                        StackView {
                            id: projectNavigationStack
                            width: parent.width
                            height: (parent.height - projectsTitle.height)
                            initialItem: projectsComponent

                            Component {
                                id: projectsComponent

                                ListView {
                                    model: bookmarkDb.bookmarks
                                    spacing: paddingSmall
                                    clip: true
                                    delegate: Button {
                                        id: bookmarkButton
                                        flat: true
                                        text: projectPicker.getDirNameForBookmark(modelData)
                                        font.pixelSize: 20
                                        onClicked: {
                                            projectNavigationStack.push(directoryComponent,
                                                                        { model: projectPicker.listBookmarkContents(modelData) })
                                        }
                                        onPressAndHold: {
                                            projectsContextMenu.selectedBookmark = modelData
                                            projectsContextMenu.open(bookmarkButton)
                                        }
                                    }

                                    Menu {
                                        id: projectsContextMenu
                                        property var selectedBookmark: null
                                        MenuItem {
                                            text: qsTr("Remove")
                                            icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")
                                            onClicked: {
                                                const bookmark = projectsContextMenu.selectedBookmark
                                                bookmarkDb.removeBookmark(bookmark)
                                                projectsContextMenu.selectedBookmark = null
                                            }
                                        }
                                    }
                                }
                            }

                            Component {
                                id: directoryComponent

                                ListView {
                                    spacing: paddingSmall
                                    clip: true
                                    delegate: Button {
                                        readonly property bool isBackButton : (modelData.name === "..")
                                        readonly property bool isDir : (modelData.type === DirectoryListing.Directory)

                                        flat: true
                                        icon.color: root.palette.button
                                        icon.source: isBackButton ? Qt.resolvedUrl("qrc:/assets/chevron.backward@2x.png")
                                                                  : (isDir ? Qt.resolvedUrl("qrc:/assets/folder@2x.png")
                                                                           : Qt.resolvedUrl("qrc:/assets/doc@2x.png"))
                                        text: isBackButton ? qsTr("Back") : modelData.name
                                        font.pixelSize: 20
                                        onClicked: {
                                            if (isBackButton) {
                                                projectNavigationStack.pop()
                                                return
                                            }

                                            console.log("listing type: " + modelData.type)

                                            if (modelData.type === DirectoryListing.Directory) {
                                                const newModel = projectPicker.listDirectoryContents(modelData.path, modelData.bookmark);
                                                projectNavigationStack.push(directoryComponent,
                                                                            { model: newModel })
                                            } else if (modelData.type === DirectoryListing.File) {
                                                openEditor(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: fileSeperator
                        color: root.palette.window
                        height: 1
                        width: parent.width
                        visible: openFilesArea.visible
                    }

                    Column {
                        id: openFilesArea
                        readonly property int usualHeight: (parent.height - fileSeperator.height) / 2
                        width: parent.width
                        height: 0
                        visible: height > 0

                        Behavior on height {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        Label {
                            id: openFilesTitle
                            text: qsTr("Open files:")
                            font.pixelSize: 16
                            color: root.palette.text
                            y: paddingSmall
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - openFilesTitle.height
                            model: openFiles.files
                            spacing: paddingSmall
                            clip: true
                            delegate: Button {
                                id: openFilesEntryButton
                                flat: true
                                text: modelData.name
                                font.pixelSize: 20
                                onClicked: {
                                    openEditor(modelData)
                                }
                                onPressAndHold: {
                                    openFilesContextMenu.selectedFile = modelData
                                    openFilesContextMenu.open(openFilesEntryButton)
                                }
                            }

                            Menu {
                                id: openFilesContextMenu
                                property var selectedFile: null
                                MenuItem {
                                    text: qsTr("Close")
                                    icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")
                                    onClicked: {
                                        let file = openFilesContextMenu.selectedFile
                                        saveFile(file)
                                        openFiles.close(file)
                                        openFilesContextMenu.selectedFile = null
                                        if (openFiles.files.length > 0)
                                            editor.file = openFiles.files[0]
                                        else
                                            editor.invalidate()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            color: root.palette.base
            width: parent.width - leftSideBar.width - paddingSmall
            height: parent.height
            clip: true
            visible: bookmarkDb.bookmarks.length > 0

            CodeEditor {
                id: editor
                anchors.fill: parent
                fileIo: fileIo
                projectPicker: projectPicker
                visible: openFiles.files.length > 0
            }
        }
    }

    Rectangle {
        id: warningSign
        anchors.centerIn: parent
        color: root.palette.base
        width: 256
        height: 256
        opacity: 0.0
        visible: opacity > 0.0
        border.color: root.palette.text
        border.width: 2
        radius: roundedCornersRadius
        clip: true

        readonly property string iconWarning: Qt.resolvedUrl("qrc:/assets/xmark.circle@2x.png")
        readonly property string iconSuccess: Qt.resolvedUrl("qrc:/assets/checkmark.circle@2x.png")
        property string iconName : ""

        onOpacityChanged: {
            if (opacity == 1.0)
                hideTimer.start()
        }

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Timer {
            id: hideTimer
            interval: 1000
            onTriggered: warningSign.opacity = 0.0
        }

        function flashSuccess(text) {
            flashingIcon.source = iconSuccess
            warningText.text = text
            opacity = 1.0
        }

        function flashWarning(text) {
            flashingIcon.source = iconWarning
            warningText.text = text
            opacity = 1.0
        }

        Column {
            anchors.centerIn: parent
            spacing: paddingSmall
            Image {
                id: flashingIcon
                width: 128
                height: 128
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                id: warningText
                color: root.palette.text
                font.pixelSize: 20
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                text: ""
            }
        }
    }

    Rectangle {
        id: consoleView
        color: root.palette.base
        radius: roundedCornersRadius
        width: (parent.width / 2)
        height: (parent.height / 2)
        x: width / 2
        y: parent.height
        visible: y < parent.height
        border.color: root.palette.text
        border.width: 2
        clip: true

        function show() {
            y = (height / 2)
        }

        function hide() {
            y = parent.height
        }

        Behavior on y {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
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
                        onClicked: {
                            consoleOutput = ""
                            consoleView.hide()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    ToolButton {
                        text: qsTr("Close")
                        onClicked: {
                            consoleView.hide()
                        }
                    }
                }
            }

            ScrollView {
                id: consoleScrollView
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                width: parent.width
                height: parent.height - consoleToolBar.height - consoleInputField.height - (paddingSmall*2)

                Text {
                    width: parent.width
                    font: fixedFont
                    text: consoleOutput
                    color: root.palette.text
                    wrapMode: TextArea.WrapAnywhere
                }
            }

            TextField {
                id: consoleInputField
                font: fixedFont
                width: parent.width
                height: font.pixelSize + (paddingSmall*2)
                background: Item { }
                placeholderText: qsTr("Input:")
                focus: consoleView.visible
                Keys.onPressed:
                    (event) => {
                        if (event.key !== Qt.Key_Return) {
                            return;
                        }

                        consoleHandler.write(text + "\n")
                        text = ""
                    }
            }
        }
    }
}
