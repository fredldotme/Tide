import QtCore
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
    flags: Qt.Window | Qt.MaximizeUsingFullscreenGeometryHint

    readonly property int paddingSmall: 8
    readonly property int paddingMedium: 16
    readonly property int roundedCornersRadius: 16
    readonly property int roundedCornersRadiusSmall: 8
    readonly property int sideBarExpandedDefault: 324
    readonly property int sideBarWidth: Math.min(sideBarExpandedDefault, width)
    readonly property int hideSideBarAutomatically: sideBarWidth < sideBarExpandedDefault ||
                                                    width < height
    readonly property bool shouldAllowSidebar: (projectList.projects.length > 0 &&
                                                openFiles.files.length > 0)
    readonly property bool padStatusBar : true

    property bool showLeftSideBar: true
    property bool compiling: false
    property font fixedFont: standardFixedFont

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
        consoleView.consoleOutput.clear()
    }

    onActiveChanged: {
        if (active) {
            cleanObsoleteProjects()
            projectList.refresh()
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
        topPadding: padStatusBar ? oskReactor.statusBarHeight : 0
        width: parent.width
        RowLayout {
            anchors.fill: parent
            spacing: paddingSmall * 2

            TideToolButton {
                id: sideBarButton
                icon.source: Qt.resolvedUrl("qrc:/assets/sidebar.left@2x.png")
                icon.color: root.palette.button
                onClicked: showLeftSideBar = !showLeftSideBar
                visible: shouldAllowSidebar
                leftPadding: paddingMedium * 2
            }

            TideToolButton {
                id: settingsButton
                icon.source: Qt.resolvedUrl("qrc:/assets/gearshape.fill@2x.png")
                icon.color: root.palette.button
                leftPadding: !shouldAllowSidebar ? paddingMedium * 2 : 0
                onClicked: {
                    if (settingsDialog.visibility) {
                        settingsDialog.hide()
                    } else {
                        settingsDialog.show()
                    }
                }
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

            TideToolButton {
                visible: openFiles.files.length > 0 && editor.file.name.endsWith(".pro")
                enabled: !projectBuilder.building
                icon.source: Qt.resolvedUrl("qrc:/assets/hammer.fill@2x.png")
                icon.color: root.palette.button
                onClicked: {
                    saveCurrentFile()
                    compiling = true

                    projectBuilder.clean()
                    projectBuilder.build()
                }
            }
            /*
            TideToolButton {
                visible: true
                enabled: !runtimeRunner.running
                icon.source: Qt.resolvedUrl("qrc:/assets/xmark.circle.fill@2x.png")
                icon.color: root.palette.button

                BusyIndicator {
                    visible: runtimeRunner.running
                    running: runtimeRunner.running
                    anchors.centerIn: parent
                }

                WasmRunner {
                    id: runtimeRunner
                    onErrorOccured:
                        (str) => {
                            consoleView.consoleOutput.append({"content": str, "stdout": false})
                            consoleView.show()
                            consoleView.consoleScrollView.positionViewAtEnd()
                        }
                }

                onClicked: {
                    runtimeRunner.run(runtime + "/out.wasm", ["/bin/bash"])
                }
            }
            */
            TideToolButton {
                visible: openFiles.files.length > 0 && editor.file.name.endsWith(".pro")
                enabled: !wasmRunner.running
                icon.source: Qt.resolvedUrl("qrc:/assets/play.fill@2x.png")
                icon.color: root.palette.button

                BusyIndicator {
                    visible: wasmRunner.running
                    running: wasmRunner.running
                    anchors.centerIn: parent
                }

                WasmRunner {
                    id: wasmRunner
                    onErrorOccured:
                        (str) => {
                            consoleView.consoleOutput.append({"content": str, "stdout": false})
                            consoleView.show()
                            consoleView.consoleScrollView.positionViewAtEnd()
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
            TideToolButton {
                icon.source: Qt.resolvedUrl("qrc:/assets/terminal.fill@2x.png")
                icon.color: root.palette.button
                rightPadding: paddingMedium * 2

                onClicked: {
                    if (consoleView.visibility)
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

    ProjectList {
        id: projectList
        bookmarkDb: BookmarkDb {
            id: bookmarkDb
        }
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
                consoleView.consoleOutput.append({"content": line, "stdout": stdout})
                consoleView.consoleScrollView.positionViewAtEnd()
            }
    }

    ProjectBuilder {
        id: projectBuilder
        onBuildError:
            (str) => {
                compiling = false
                console.log("Output: " + str);
                consoleView.consoleOutput.append({"content": str, "stdout": false})
                consoleView.consoleScrollView.positionViewAtEnd()
                consoleView.show()
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
            //runtimeRunner.prepareStdio(spec)
        });
        iosSystem.setupStdIo()

        sysrootManager.installBundledSysroot();

        projectBuilder.commandRunner = iosSystem
        projectBuilder.setSysroot(sysroot);
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

        if (hideSideBarAutomatically)
            showLeftSideBar = false
    }

    // Main container
    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.bottomMargin: oskReactor.oskVisible ? oskReactor.oskHeight : 0;

        Component.onCompleted: {
            oskReactor.item = mainContainer
        }

        ColumnLayout {
            id: startPage
            anchors.centerIn: parent
            spacing: paddingMedium
            visible: projectList.projects.length === 0

            readonly property int sideLength : 32

            Text {
                width: parent.width
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                font.pixelSize: startPage.sideLength
                color: root.palette.mid
                text: qsTr("Import or create a project and start developing!")
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                width: parent.width
                spacing: paddingMedium
                Layout.alignment: Qt.AlignHCenter

                TideButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/plus.app@2x.png")
                    icon.width: startPage.sideLength
                    icon.height: startPage.sideLength
                    font.pixelSize: startPage.sideLength
                    height: startPage.sideLength
                    color: root.palette.button
                    text: qsTr("Create")
                    onClicked: createProjectDialog.open()
                }
                TideButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/square.and.arrow.down.on.square@2x.png")
                    icon.width: startPage.sideLength
                    icon.height: startPage.sideLength
                    font.pixelSize: startPage.sideLength
                    height: startPage.sideLength
                    color: root.palette.button
                    text: qsTr("Import")
                    onClicked: projectPicker.startImport()
                }
            }
        }

        Row {
            id: mainView
            anchors.fill: parent
            spacing: 1
            visible: projectList.projects.length > 0
            onVisibleChanged: mainView.forceLayout()

            Pane {
                id: leftSideBar
                width: showLeftSideBar ? sideBarWidth : 0
                height: parent.height
                clip: true

                Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic; }
                }

                onWidthChanged: {
                    if (width > 0 && width < sideBarWidth)
                        return;

                    editor.refreshLineNumbers()
                }

                Pane {
                    anchors.fill: parent

                    Column {
                        width: parent.width
                        height: parent.height

                        Column {
                            width: parent.width
                            height: openFilesArea.height == 0 ?
                                        parent.height :
                                        parent.height / 2

                            Behavior on height {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }

                            StackView {
                                id: projectNavigationStack
                                width: parent.width
                                height: parent.height
                                initialItem: projectsComponent
                                popEnter: Transition {
                                    NumberAnimation {
                                        from: 0.0
                                        to: 1.0
                                        properties: "opacity"
                                        duration: 100
                                    }
                                }
                                pushExit: Transition {
                                    NumberAnimation {
                                        from: 1.0
                                        to: 0.0
                                        properties: "opacity"
                                        duration: 100
                                    }
                                }

                                Component {
                                    id: projectsComponent

                                    ListView {
                                        headerPositioning: ListView.PullBackHeader
                                        header: ToolBar {
                                            clip: true
                                            width: projectNavigationStack.width
                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: paddingSmall * 2
                                                ToolButton {
                                                    text: qsTr("Create")
                                                    icon.source: Qt.resolvedUrl("qrc:/assets/plus.app@2x.png")
                                                    icon.color: root.palette.button
                                                    leftPadding: paddingMedium
                                                    onClicked: createProjectDialog.open()
                                                }
                                                ToolButton {
                                                    text: qsTr("Import")
                                                    icon.source: Qt.resolvedUrl("qrc:/assets/square.and.arrow.down.on.square@2x.png")
                                                    icon.color: root.palette.button
                                                    leftPadding: paddingSmall
                                                    onClicked: projectPicker.startImport()
                                                }
                                            }
                                        }

                                        Connections {
                                            target: projectCreator
                                            function onProjectCreated() {
                                                projectList.refresh()
                                            }
                                        }

                                        width: parent.width
                                        model: projectList.projects
                                        spacing: paddingMedium
                                        topMargin: paddingMedium
                                        clip: true
                                        delegate: TideButton {
                                            id: bookmarkButton
                                            text: modelData.isBookmark ?
                                                      projectPicker.getDirNameForBookmark(modelData.bookmark) :
                                                      modelData.name
                                            font.pixelSize: 20
                                            color: root.palette.button
                                            icon.source: modelData.isBookmark ?
                                                             Qt.resolvedUrl("qrc:/assets/bookmark@2x.png") :
                                                             Qt.resolvedUrl("qrc:/assets/folder@2x.png")

                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                leftMargin: paddingMedium
                                            }

                                            onClicked: {
                                                projectNavigationStack.push(directoryComponent,
                                                                            {project: modelData})
                                            }
                                            onPressAndHold: {
                                                projectsContextMenu.selectedProject = modelData
                                                projectsContextMenu.open()
                                            }
                                        }

                                        Menu {
                                            id: projectsContextMenu
                                            property var selectedProject: null
                                            MenuItem {
                                                text: qsTr("Remove")
                                                icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")
                                                onClicked: {
                                                    if (projectsContextMenu.selectedProject.isBookmark) {
                                                        const bookmark = projectsContextMenu.selectedProject.bookmark
                                                        openFiles.closeAllByBookmark(bookmark)
                                                        bookmarkDb.removeBookmark(bookmark)
                                                    } else {
                                                        projectList.removeProject(projectsContextMenu.selectedProject.path)
                                                    }
                                                    projectsContextMenu.selectedProject = null
                                                }
                                            }
                                        }
                                    }
                                }

                                Component {
                                    id: directoryComponent

                                    ListView {
                                        id: directoryListView
                                        property var project : null

                                        function refresh() {
                                            if (project.isBookmark) {
                                                model = projectPicker.listBookmarkContents(project.bookmark)
                                            } else {
                                                model = projectList.listDirectoryContents(project.path)
                                            }
                                        }

                                        Component.onCompleted: {
                                            refresh()
                                        }

                                        Connections {
                                            target: fileIo
                                            function onDirectoryCreated(path, parent) {
                                                if (parent === project.path) {
                                                    directoryListView.refresh();
                                                }
                                            }
                                            function onFileCreated(path, parent) {
                                                if (parent === project.path) {
                                                    directoryListView.refresh()
                                                }
                                            }
                                        }

                                        headerPositioning: ListView.PullBackHeader
                                        header: ToolBar {
                                            width: projectNavigationStack.width
                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: paddingSmall * 2
                                                TideToolButton {
                                                    text: qsTr("New file")
                                                    icon.source: Qt.resolvedUrl("qrc:/assets/doc.badge.plus@2x.png")
                                                    icon.color: root.palette.button
                                                    leftPadding: paddingMedium
                                                    onClicked: {
                                                        newFileDialog.rootPath = directoryListView.project.path
                                                        newFileDialog.open();
                                                    }
                                                }
                                                TideToolButton {
                                                    text: qsTr("New directory")
                                                    icon.source: Qt.resolvedUrl("qrc:/assets/plus.rectangle.on.folder@2x.png")
                                                    icon.color: root.palette.button
                                                    leftPadding: paddingSmall
                                                    onClicked: {
                                                        newDirectoryDialog.rootPath = directoryListView.project.path
                                                        newDirectoryDialog.open();
                                                    }
                                                }
                                            }
                                        }

                                        topMargin: paddingMedium
                                        spacing: paddingMedium
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
                                            pressAnimation: !isBackButton
                                            longPressEnabled: !isBackButton

                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                leftMargin: paddingMedium
                                            }

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
                                                                                { project: modelData })
                                                } else if (modelData.type === DirectoryListing.File) {
                                                    openEditor(modelData)
                                                }
                                            }

                                            onPressAndHold: {
                                                directoryListViewContextMenu.open()
                                            }

                                            Connections {
                                                target: fileIo
                                                function onPathDeleted(path) {
                                                    if (path === project.path) {
                                                        directoryListView.refresh();
                                                    }
                                                }
                                            }

                                            Menu {
                                                id: directoryListViewContextMenu
                                                readonly property bool isDir : (modelData.type === DirectoryListing.Directory)

                                                MenuItem {
                                                    text: qsTr("Delete")
                                                    icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")
                                                    onClicked: {
                                                        if (!isDir) {
                                                            openFiles.close(modelData)
                                                            if (openFiles.files.length > 0)
                                                                editor.file = openFiles.files[0]
                                                            else
                                                                editor.invalidate()
                                                        }

                                                        fileIo.deleteFileOrDirectory(modelData.path)
                                                        directoryListView.refresh()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            id: openFilesArea
                            readonly property int usualHeight: (parent.height) / 2
                            width: parent.width
                            height: 0

                            Behavior on height {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }

                            ListView {
                                width: parent.width
                                height: parent.height
                                topMargin: paddingMedium
                                model: openFiles.files
                                spacing: paddingMedium
                                headerPositioning: ListView.PullBackHeader
                                header: ToolBar {
                                    id: openFilesAreaToolbar
                                    width: projectNavigationStack.width

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: paddingSmall * 2
                                        TideToolButton {
                                            Layout.fillWidth: true
                                            icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")
                                            text: qsTr("Close all")
                                            font.pixelSize: 16
                                            onClicked: {
                                                console.log("Closing all " + openFiles.files.length + " files")
                                                for (let i = openFiles.files.length - 1; i >= 0; i--) {
                                                    console.log("Closing: " + i)
                                                    openFiles.close(openFiles.files[i])
                                                }
                                            }
                                        }
                                    }
                                }

                                clip: true
                                delegate: TideButton {
                                    readonly property bool isProject : modelData.name.endsWith(".pro")

                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        leftMargin: paddingMedium
                                    }
                                    id: openFilesEntryButton
                                    icon.source: isProject ? Qt.resolvedUrl("qrc:/assets/hammer@2x.png")
                                                           : Qt.resolvedUrl("qrc:/assets/doc@2x.png")
                                    color: (editor.file.path === modelData.path) ?
                                               root.palette.button :
                                               root.palette.dark
                                    text: modelData.name
                                    font.pixelSize: 20
                                    onClicked: {
                                        saveCurrentFile()
                                        openEditor(modelData)
                                    }
                                    onPressAndHold: {
                                        openFilesContextMenu.selectedFile = modelData
                                        openFilesContextMenu.open()
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
                width: parent.width - leftSideBar.width
                height: parent.height
                clip: true
                visible: projectList.projects.length > 0

                CodeEditor {
                    id: editor
                    anchors.fill: parent
                    fileIo: fileIo
                    projectPicker: projectPicker
                    projectBuilder: projectBuilder
                    openFiles: openFiles
                    onSaveRequested: saveCurrentFile()
                }
            }
        }

        Rectangle {
            id: dialogShadow
            anchors.fill: parent
            color: root.palette.shadow
            opacity: 0.0
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
                        mouse.accepted = true
                    }
            }
        }

        SettingsDialog {
            id: settingsDialog
            width: (parent.width / 2)
            height: (parent.height / 2)
        }

        ListModel {
            id: availableFontSizes
            ListElement {
                text: "10"
            }
            ListElement {
                text: "12"
            }
            ListElement {
                text: "14"
            }
            ListElement {
                text: "16"
            }
            ListElement {
                text: "18"
            }
            ListElement {
                text: "20"
            }
            ListElement {
                text: "22"
            }
            ListElement {
                text: "24"
            }
            ListElement {
                text: "26"
            }
            ListElement {
                text: "28"
            }
            ListElement {
                text: "30"
            }
            ListElement {
                text: "32"
            }
        }

        Settings {
            id: settings
            property int fontSize: 2
            onFontSizeChanged: {
                fixedFont.pixelSize = parseInt(availableFontSizes.get(fontSize).text)
                editor.refreshLineNumbers()
            }

            property bool autocomplete: true
            property bool autoformat: true
            property int formatStyle : CppFormatter.LLVM
        }

        ConsoleView {
            id: consoleView
            width: (parent.width / 8) * 6
            height: (parent.height / 8) * 6
        }

        Dialog {
            id: createProjectDialog
            title: qsTr("Create project:");
            modal: true
            anchors.centerIn: parent
            standardButtons: Dialog.Ok | Dialog.Cancel
            Component.onCompleted: imFixer.setupImEventFilter(projectName)

            ProjectCreator {
                id: projectCreator
            }

            TextField {
                id: projectName
                width: parent.width
                placeholderText: qsTr("Name:")
                validator: RegularExpressionValidator {
                    regularExpression: /^[a-zA-Z0-9_.-]*$/
                }
            }

            onAccepted: projectCreator.createProject(projectName.text)
        }

        Dialog {
            id: newFileDialog
            title: qsTr("New file:");
            modal: true
            anchors.centerIn: parent
            standardButtons: Dialog.Ok | Dialog.Cancel
            Component.onCompleted: imFixer.setupImEventFilter(fileName)
            property string rootPath: ""

            TextField {
                id: fileName
                width: parent.width
                placeholderText: qsTr("Name:")
                validator: RegularExpressionValidator {
                    regularExpression: /^[a-zA-Z0-9_.-]*$/
                }
                focus: newFileDialog.opened
            }

            onAccepted: {
                fileIo.createFile(rootPath + "/" + fileName.text)
                newFileDialog.rootPath = ""
                fileName.text = ""
            }

            onRejected: {
                newFileDialog.rootPath = ""
                fileName.text = ""
            }
        }

        Dialog {
            id: newDirectoryDialog
            title: qsTr("New directory:");
            modal: true
            anchors.centerIn: parent
            standardButtons: Dialog.Ok | Dialog.Cancel
            Component.onCompleted: imFixer.setupImEventFilter(directoryName)
            property string rootPath: ""

            TextField {
                id: directoryName
                width: parent.width
                placeholderText: qsTr("Name:")
                validator: RegularExpressionValidator {
                    regularExpression: /^[a-zA-Z0-9_.-]*$/
                }
                focus: newDirectoryDialog.opened
            }

            onAccepted: {
                fileIo.createDirectory(rootPath + "/" + directoryName.text)
                newDirectoryDialog.rootPath = ""
                directoryName.text = ""
            }

            onRejected: {
                newDirectoryDialog.rootPath = ""
                directoryName.text = ""
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
}
