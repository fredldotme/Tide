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
    readonly property int paddingMedium: 16
    readonly property int roundedCornersRadius: 16
    readonly property int sideBarWidth: 300
    readonly property bool shouldAllowSidebar: (bookmarkDb.bookmarks.length > 0 &&
                                                openFiles.files.length > 0)

    property bool showLeftSideBar: true
    property bool compiling: false

    function saveCurrentFile() {
        if (editor.file == null || editor.invalidated)
            return

        const file = editor.file
        const path = projectPicker.openBookmark(file.bookmark)
        fileIo.writeFile(file.path, editor.text)
        projectPicker.closeFile(path);
        editor.reloadAst()
    }

    function clearConsoleOutput() {
        consoleOutput.clear()
    }

    onActiveChanged: {
        if (active) {
            cleanObsoleteProjects()
        } else {
            saveCurrentFile()
        }
    }

    onWidthChanged: {
        editor.refreshLineNumbers()

        // Hide the sidebar
        if (width < height && shouldAllowSidebar)
            showLeftSideBar = false
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            spacing: paddingSmall * 2

            ToolButton {
                id: sideBarButton
                icon.source: Qt.resolvedUrl("qrc:/assets/sidebar.left@2x.png")
                icon.color: root.palette.button
                onClicked: showLeftSideBar = !showLeftSideBar
                visible: shouldAllowSidebar
                leftPadding: paddingMedium
            }

            ToolButton {
                text: qsTr("Import")
                icon.source: Qt.resolvedUrl("qrc:/assets/square.and.arrow.down.on.square@2x.png")
                icon.color: root.palette.button
                onClicked: projectPicker.startImport()
                leftPadding: sideBarButton.visible ? 0 : paddingMedium
            }

            Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                color: root.palette.button
                text: compiling ? qsTr("Compiling... get your swords!") :
                                  ""
                elide: Text.ElideRight
                font.bold: true
                horizontalAlignment: Label.AlignHCenter
                verticalAlignment: Label.AlignVCenter
            }

            ToolButton {
                visible: openFiles.files.length > 0 && editor.file.name.endsWith(".pro")
                icon.source: Qt.resolvedUrl("qrc:/assets/hammer.fill@2x.png")
                icon.color: root.palette.button
                onClicked: {
                    saveCurrentFile()
                    compiling = true

                    projectBuilder.clean()
                    projectBuilder.build()
                }
            }
            ToolButton {
                visible: openFiles.files.length > 0 && editor.file.name.endsWith(".pro")
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
                            consoleOutput.append({"content": str, "stdout": false})
                            consoleView.show()
                            consoleScrollView.positionViewAtEnd()
                        }
                }

                onClicked: {
                    if (!editor)
                        return;

                    consoleView.show()
                    wasmRunner.kill();
                    wasmRunner.run(projectBuilder.runnableFile(), [])
                }
            }
            ToolButton {
                icon.source: Qt.resolvedUrl("qrc:/assets/terminal.fill@2x.png")
                icon.color: root.palette.button
                rightPadding: paddingMedium

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
            console.log("Command retuned: " + ret);
        }
    }

    Console {
        id: consoleHandler
        onContentRead:
            (line, stdout) => {
                console.log("Output: " + line);
                consoleOutput.append({"content": line, "stdout": stdout})
                consoleScrollView.positionViewAtEnd()
            }
    }

    ProjectBuilder {
        id: projectBuilder
        onBuildError:
            (str) => {
                compiling = false
                console.log("Output: " + str);
                consoleOutput.append({"content": str, "stdout": false})
                consoleScrollView.positionViewAtEnd()
                warningSign.flashWarning(qsTr("Build failed!"))
            }
        onBuildSuccess: {
            compiling = false
            warningSign.flashSuccess(qsTr("Build successful!"))
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

        projectBuilder.commandRunner = iosSystem
        projectBuilder.setSysroot(sysroot);

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
        saveCurrentFile()

        openFiles.push(modelData)
        editor.file = modelData

        // Also load project in case it's a .pro
        if (modelData.path.endsWith(".pro"))
            projectBuilder.loadProject(modelData.path)
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
                        spacing: paddingSmall
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
                                    spacing: paddingSmall * 2
                                    clip: true
                                    delegate: TideButton {
                                        id: bookmarkButton
                                        text: projectPicker.getDirNameForBookmark(modelData)
                                        font.pixelSize: 20
                                        color: root.palette.button
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
                                                openFiles.closeAllByBookmark(bookmark)
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
                                    delegate: TideButton {
                                        readonly property bool isBackButton : (modelData.name === "..")
                                        readonly property bool isDir : (modelData.type === DirectoryListing.Directory)
                                        readonly property bool isProject : (modelData.name.endsWith(".pro"))

                                        color: root.palette.button
                                        icon.color: root.palette.button
                                        icon.source: isBackButton ? Qt.resolvedUrl("qrc:/assets/chevron.backward@2x.png")
                                                                  : (isDir ? Qt.resolvedUrl("qrc:/assets/folder@2x.png")
                                                                           : isProject ? Qt.resolvedUrl("qrc:/assets/hammer@2x.png")
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
                        spacing: paddingSmall

                        Behavior on height {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        Label {
                            id: openFilesTitle
                            text: qsTr("Open files:")
                            font.pixelSize: 16
                            color: root.palette.text
                            y: paddingSmall
                            topPadding: paddingSmall
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
                                    saveCurrentFile()
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

                onSaveRequested: saveCurrentFile()
            }
        }
    }

    Rectangle {
        id: consoleShadow
        anchors.fill: parent
        color: root.palette.shadow
        opacity: 0.0
        visible: opacity > 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: consoleShadow.consoleAnimation
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
                    mouse.accepted = true
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
        border.width: 1
        clip: true

        function show() {
            consoleShadow.opacity = 0.3
            y = (height / 2)
            hideStdOut = false
        }

        function hide() {
            consoleShadow.opacity = 0.0
            y = parent.height
        }

        property bool hideStdOut: false

        ListModel {
            id: consoleOutput
        }

        Behavior on y {
            NumberAnimation {
                duration: consoleShadow.consoleAnimation
                easing.type: Easing.OutCubic
            }
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
                        leftPadding: paddingMedium
                        onClicked: {
                            clearConsoleOutput()
                        }
                    }
                    ToolButton {
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
                        text: qsTr("Close")
                        font.bold: true
                        rightPadding: paddingMedium
                        onClicked: {
                            consoleView.hide()
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
                        wrapMode: TextArea.WrapAnywhere
                        font: fixedFont
                        text: content
                        color: root.palette.text
                        width: consoleScrollView.width
                        height: isAllowedLine ? contentHeight : 0
                        visible: height > 0

                        Behavior on height {
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
            flashingIcon.icon.source = iconSuccess
            warningText.text = text
            opacity = 1.0
        }

        function flashWarning(text) {
            flashingIcon.icon.source = iconWarning
            warningText.text = text
            opacity = 1.0
        }

        Column {
            anchors.centerIn: parent
            spacing: paddingSmall

            // Button gives us coloring for free, so use it as a clutch for now
            Button {
                id: flashingIcon
                width: 128
                height: 128
                icon.width: width
                icon.height: height
                anchors.horizontalCenter: parent.horizontalCenter
                flat: true
                enabled: false
                icon.color: root.palette.text
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
}
