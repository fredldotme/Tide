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
    readonly property int roundedCornersRadiusSmall: 8
    readonly property int roundedCornersRadius: 16
    readonly property int roundedCornersRadiusMedium: 24
    readonly property int sideBarExpandedDefault: 324
    readonly property int sideBarWidth: width > height ? Math.min(sideBarExpandedDefault, width) : width
    readonly property bool shouldAllowSidebar: (projectList.projects.length > 0 &&
                                                openFiles.files.length > 0)
    readonly property bool padStatusBar : true
    readonly property int headerItemHeight : 48
    readonly property int topBarHeight : 72

    property bool showLeftSideBar: true
    property bool compiling: false
    property bool releaseRequested : false
    property font fixedFont: standardFixedFont

    signal fileSaved()

    function saveCurrentFile() {
        if (editor.file == null || editor.invalidated)
            return

        const file = editor.file
        const path = projectPicker.openBookmark(file.bookmark)
        fileIo.writeFile(file.path, editor.text)
        projectPicker.closeFile(path);
        editor.reloadAst()

        fileSaved()
    }

    function clearConsoleOutput() {
        consoleView.consoleOutput.clear()
    }

    function attemptRun() {
        if (editor.invalidated)
            return;

        const killOnly = wasmRunner.running

        wasmRunner.kill();
        if (killOnly)
            return;

        consoleView.show();
        wasmRunner.run(projectBuilder.runnableFile(), [])
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
        else
            showLeftSideBar = true
    }

    header: Pane {
        topPadding: padStatusBar ? oskReactor.statusBarHeight : 0
        width: parent.width
        height: topBarHeight

        Column {
            anchors.fill: parent
            spacing: paddingSmall * 2

            RowLayout {
                spacing: paddingSmall * 2
                width: parent.width

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
                    visible: openFiles.files.length > 0 && projectBuilder.projectFile !== ""
                    enabled: !projectBuilder.building && !wasmRunner.running
                    icon.source: Qt.resolvedUrl("qrc:/assets/hammer.fill@2x.png")
                    icon.color: root.palette.button
                    onClicked: {
                        saveCurrentFile()
                        compiling = true

                        projectBuilder.clean()
                        projectBuilder.build()
                    }

                    BusyIndicator {
                        visible: projectBuilder.building
                        running: projectBuilder.building
                        anchors.centerIn: parent
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
                    visible: openFiles.files.length > 0 && projectBuilder.projectFile !== ""
                    enabled: !projectBuilder.building
                    icon.source: !wasmRunner.running ?
                                     Qt.resolvedUrl("qrc:/assets/play.fill@2x.png") :
                                     Qt.resolvedUrl("qrc:/assets/stop.fill@2x.png")
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
                        root.attemptRun()
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

    ProjectCreator {
        id: projectCreator
    }

    FileIo {
        id: fileIo
    }

    OpenFilesManager {
        id: openFiles
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
                releaseRequested = false
                warningSign.flashWarning(qsTr("Build failed!"))
            }
        onBuildSuccess: {
            compiling = false
            warningSign.flashSuccess(qsTr("Build successful!"))

            if (releaseRequested) {
                releaseRequested = false
                Qt.openUrlExternally("shareddocuments://" + projectBuilder.runnableFile())
            }
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

        // Also load project in case it's a project
        if (modelData.path.endsWith(".pro") /* || modelData.path.endsWith("CMakeLists.txt")*/)
            projectBuilder.loadProject(modelData.path)

        if (root.width < root.height)
            showLeftSideBar = false
    }

    function openEditorFile(file) {
        const listing = openFiles.open(file);
        openEditor(listing)
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
                    onClicked: {
                        let createProjectDialog = createProjectDialogComponent.createObject(root)
                        createProjectDialog.done.connect(function() {
                            createProjectDialog.destroy()
                        })
                        createProjectDialog.open()
                    }
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
                topInset: 0
                bottomInset: 0
                topPadding: 0
                leftPadding: 0
                rightPadding: 0

                Behavior on width {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic; }
                }

                onWidthChanged: {
                    if (width > 0 && width < sideBarWidth)
                        return;

                    editor.refreshLineNumbers()
                }

                Pane {
                    anchors.fill: parent
                    topInset: 0
                    leftInset: 0
                    rightInset: 0
                    bottomInset: 0
                    topPadding: paddingMedium
                    bottomPadding: paddingMedium

                    Column {
                        width: parent.width
                        height: parent.height
                        spacing: paddingMedium

                        Grid {
                            id: contextField
                            width: parent.width
                            clip: true
                            columns: {
                                let columns = 0;
                                let rowWidth = 0;
                                for (let i = 0; i < children.length; i++) {
                                    if (rowWidth + children[i].width < width) {
                                        ++columns
                                        rowWidth += children[i].width
                                    } else {
                                        break
                                    }
                                }
                                return columns;
                            }

                            readonly property bool visibility: openFiles.files.length > 0
                            height: visibility ? childrenRect.height : 0
                            visible: height > 0

                            Behavior on height {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                            }

                            TideToolButton {
                                id: contextFieldSearchButton
                                leftPadding: paddingSmall
                                text: qsTr("Find/replace")
                                icon.source: Qt.resolvedUrl("qrc:/assets/magnifyingglass.circle.fill@2x.png")
                                icon.color: root.palette.button
                                flat: true

                                //Layout.alignment: Qt.AlignHCenter

                                onClicked: {
                                    let root = editor.file.path
                                    if (contextDialog.visibility)
                                        contextDialog.hide()
                                    else
                                        contextDialog.show(root)
                                }
                            }

                            TideToolButton {
                                id: formatButton
                                leftPadding: paddingSmall
                                text: qsTr("Autoformat")
                                icon.source: Qt.resolvedUrl("qrc:/assets/line.3.horizontal.circle.fill@2x.png")
                                icon.color: root.palette.button
                                flat: false
                                readonly property bool visibility : editor.canUseAutocomplete
                                height: visibility ? implicitHeight : 0

                                Layout.alignment: Qt.AlignHCenter

                                onClicked: {
                                    editor.format()
                                }
                            }

                            TideToolButton {
                                id: shareButton
                                leftPadding: paddingSmall
                                text: qsTr("Share")
                                icon.source: Qt.resolvedUrl("qrc:/assets/square.and.arrow.up.circle.fill@2x.png")
                                icon.color: root.palette.button
                                flat: false

                                Layout.alignment: Qt.AlignHCenter

                                onClicked: {
                                    const coords = shareButton.mapToGlobal(0, 0)
                                    const pos = Qt.rect(coords.x, coords.y, width, height)
                                    saveCurrentFile()
                                    iosSystem.share("", "file://" + editor.file.path, pos)
                                }
                            }

                            TideToolButton {
                                id: releaseButton
                                leftPadding: paddingSmall
                                text: qsTr("Release")
                                icon.source: Qt.resolvedUrl("qrc:/assets/briefcase.circle.fill@2x.png")
                                icon.color: root.palette.button
                                flat: false
                                readonly property bool visibility : projectBuilder.projectFile !== ""
                                height: visibility ? implicitHeight : 0

                                Layout.alignment: Qt.AlignHCenter

                                onClicked: {
                                    releaseRequested = true
                                    projectBuilder.clean()
                                    projectBuilder.build()
                                }
                            }
                        }

                        Column {
                            y: paddingSmall
                            width: parent.width
                            height: openFilesArea.height == 0 ?
                                        parent.height :
                                        (parent.height / 2) - (contextField.height / 2) - (paddingMedium)

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

                                    Rectangle {
                                        width: parent.width
                                        radius: roundedCornersRadiusMedium
                                        color: root.palette.base
                                        clip: true

                                        ListView {
                                            headerPositioning: ListView.PullBackHeader
                                            header: Item {
                                                clip: true
                                                width: projectNavigationStack.width
                                                height: root.headerItemHeight
                                                RowLayout {
                                                    anchors.fill: parent
                                                    spacing: paddingSmall * 2
                                                    ToolButton {
                                                        text: qsTr("Create")
                                                        icon.source: Qt.resolvedUrl("qrc:/assets/plus.app@2x.png")
                                                        icon.color: root.palette.button
                                                        leftPadding: paddingMedium
                                                        onClicked: {
                                                            let createProjectDialog = createProjectDialogComponent.createObject(root)
                                                            createProjectDialog.done.connect(function() {
                                                                createProjectDialog.destroy()
                                                            })
                                                            createProjectDialog.open()
                                                        }
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
                                            height: parent.height
                                            spacing: paddingSmall
                                            model: projectList.projects
                                            topMargin: paddingMedium
                                            clip: true

                                            delegate: FileListingButton {
                                                id: bookmarkButton
                                                text: modelData.isBookmark ?
                                                          projectPicker.getDirNameForBookmark(modelData.bookmark) :
                                                          modelData.name
                                                font.pixelSize: 20
                                                height: font.pixelSize + (paddingSmall * 2)
                                                textColor: root.palette.button
                                                icon.source: modelData.isBookmark ?
                                                                 Qt.resolvedUrl("qrc:/assets/bookmark@2x.png") :
                                                                 Qt.resolvedUrl("qrc:/assets/folder@2x.png")

                                                anchors {
                                                    left: parent.left
                                                    leftMargin: paddingMedium
                                                    right: parent.right
                                                    bottomMargin: paddingMedium
                                                }

                                                onClicked: {
                                                    projectNavigationStack.push(directoryComponent,
                                                                                {project: modelData})
                                                }
                                                onPressAndHold: {
                                                    let projectsContextMenu = projectsContextMenuComponent.createObject(bookmarkButton);
                                                    projectsContextMenu.selectedProject = modelData
                                                    projectsContextMenu.open()
                                                }
                                            }

                                            Component {
                                                id: projectsContextMenuComponent
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
                                    }
                                }

                                Component {
                                    id: directoryComponent

                                    Rectangle {
                                        width: parent.width
                                        height: parent.height
                                        radius: roundedCornersRadiusMedium
                                        color: root.palette.base
                                        clip: true

                                        property alias model: directoryListView.model
                                        property alias project: directoryListView.project

                                        ListView {
                                            id: directoryListView
                                            width: parent.width
                                            height: parent.height
                                            spacing: paddingSmall
                                            property var project : null

                                            function refresh() {
                                                if (project.isBookmark) {
                                                    model = projectPicker.listBookmarkContents(project.bookmark)
                                                } else {
                                                    model = projectList.listDirectoryContents(project.path)
                                                }
                                            }

                                            function getDetailText(listing) {
                                                if (listing.type === DirectoryListing.Directory) {
                                                    return qsTr("%1 contents").arg(fileIo.directoryContents(listing.path))
                                                } else {
                                                    return qsTr("%1 bytes").arg(fileIo.fileSize(listing.path))
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
                                            header: Item {
                                                width: projectNavigationStack.width
                                                height: root.headerItemHeight
                                                RowLayout {
                                                    anchors.fill: parent
                                                    spacing: paddingSmall * 2
                                                    TideToolButton {
                                                        text: qsTr("New file")
                                                        icon.source: Qt.resolvedUrl("qrc:/assets/doc.badge.plus@2x.png")
                                                        icon.color: root.palette.button
                                                        leftPadding: paddingMedium
                                                        onClicked: {
                                                            let newFileDialog = newFileDialogComponent.createObject(root)
                                                            newFileDialog.done.connect(function() {
                                                                newFileDialog.destroy()
                                                            })
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
                                                            let newDirectoryDialog = newDirectoryDialogComponent.createObject(root)
                                                            newDirectoryDialog.done.connect(function() {
                                                                newDirectoryDialog.destroy()
                                                            })
                                                            newDirectoryDialog.rootPath = directoryListView.project.path
                                                            newDirectoryDialog.open();
                                                        }
                                                    }
                                                }
                                            }

                                            topMargin: paddingMedium
                                            delegate: FileListingButton {
                                                id: fileListingButton
                                                readonly property bool isBackButton : (modelData.name === "..")
                                                readonly property bool isDir : (modelData.type === DirectoryListing.Directory)
                                                readonly property bool isProject : (modelData.name.endsWith(".pro") /* || modelData.name.endsWith("CMakeLists.txt") */)

                                                textColor: root.palette.button
                                                icon.color: root.palette.button
                                                icon.source: isBackButton ? Qt.resolvedUrl("qrc:/assets/chevron.backward@2x.png")
                                                                          : (isDir ? Qt.resolvedUrl("qrc:/assets/folder@2x.png")
                                                                                   : isProject ? Qt.resolvedUrl("qrc:/assets/hammer@2x.png")
                                                                                               : Qt.resolvedUrl("qrc:/assets/doc@2x.png"))
                                                text: isBackButton ? qsTr("Back") : modelData.name
                                                detailText: isBackButton ? "" : directoryListView.getDetailText(modelData)
                                                pressAnimation: !isBackButton
                                                longPressEnabled: !isBackButton

                                                Connections {
                                                    target: root
                                                    function onFileSaved() {
                                                        if (isBackButton)
                                                            return;

                                                        // Refresh sizes and file contents
                                                        fileListingButton.detailText = directoryListView.getDetailText(modelData)
                                                    }
                                                }

                                                anchors {
                                                    left: parent.left
                                                    leftMargin: paddingMedium
                                                    right: parent.right
                                                }

                                                font.pixelSize: 20
                                                height: font.pixelSize + + detailControl.font.pixelSize + (paddingSmall * 2)

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
                        }

                        Column {
                            id: openFilesArea
                            readonly property int usualHeight: (parent.height / 2) - (contextField.height / 2) - (paddingMedium / 2)
                            width: parent.width
                            height: openFiles.files.length > 0 ? openFilesArea.usualHeight : 0

                            Behavior on height {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }

                            Rectangle {
                                width: parent.width
                                height: parent.height
                                radius: roundedCornersRadiusMedium
                                color: root.palette.base
                                clip: true

                                ListView {
                                    id: openfilesListView
                                    width: parent.width
                                    height: parent.height
                                    topMargin: paddingMedium
                                    model: openFiles.files
                                    spacing: paddingSmall

                                    headerPositioning: ListView.PullBackHeader
                                    header: Item {
                                        id: openFilesAreaToolbar
                                        width: projectNavigationStack.width
                                        height: root.headerItemHeight

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
                                    delegate: OpenFileListingButton {
                                        readonly property bool isProject : modelData.name.endsWith(".pro") // || modelData.name.endsWith("CMakeLists.txt")
                                        readonly property bool isActiveProject: modelData.path === projectBuilder.projectFile
                                        radius: roundedCornersRadiusSmall

                                        anchors {
                                            left: parent.left
                                            leftMargin: paddingMedium
                                            right: parent.right
                                            rightMargin: paddingMedium
                                        }
                                        id: openFilesEntryButton
                                        icon.source: isProject ? (isActiveProject ?
                                                                      Qt.resolvedUrl("qrc:/assets/hammer.circle@2x.png") :
                                                                      Qt.resolvedUrl("qrc:/assets/hammer@2x.png"))
                                                               : Qt.resolvedUrl("qrc:/assets/doc@2x.png")
                                        color: (editor.file.path === modelData.path) ?
                                                   root.palette.active.button :
                                                   "transparent"
                                        textColor: (editor.file.path === modelData.path) ?
                                                       root.palette.buttonText :
                                                       root.palette.button
                                        text: modelData.name
                                        detailText: (editor.file.path === modelData.path) && editor.changed ?
                                                        qsTr("Unsaved") : ""
                                        height: font.pixelSize + detailControl.height + (paddingSmall * 2)
                                        font.pixelSize: 20
                                        onClicked: {
                                            saveCurrentFile()
                                            openEditor(modelData)
                                        }
                                        onPressAndHold: {
                                            let openFilesContextMenu = openFilesContextMenuComponent.createObject(openFilesEntryButton)
                                            openFilesContextMenu.selectedFile = modelData
                                            openFilesContextMenu.open()
                                        }
                                    }

                                    Component {
                                        id: openFilesContextMenuComponent
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
                }
            }

            Item {
                width: parent.width - leftSideBar.width
                height: parent.height
                clip: true
                visible: projectList.projects.length > 0

                CodeEditor {
                    id: editor
                    anchors.fill: parent
                    anchors {
                        topMargin: paddingMedium
                        rightMargin: paddingMedium
                        leftMargin: paddingMedium
                        bottomMargin: paddingMedium + paddingSmall
                    }

                    fileIo: fileIo
                    projectPicker: projectPicker
                    projectBuilder: projectBuilder
                    openFiles: openFiles
                    onSaveRequested: saveCurrentFile()
                    onFindRequested: contextDialog.show(editor.file.path)
                    onBuildRequested: {
                        projectBuilder.clean()
                        projectBuilder.build()
                    }
                    onRunRequested: {
                        wasmRunner.run()
                    }

                    onInvalidatedChanged: {
                        if (invalidated)
                            projectBuilder.projectFile = ""
                    }
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
            width: parent.width <= sideBarWidth ?
                       sideBarWidth :
                       (parent.width / 2)
            height: width === sideBarExpandedDefault ?
                        parent.height :
                        (parent.height / 2)
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

        ContextView {
            id: contextDialog
            width: (parent.width / 8) * 6
            height: (parent.height / 8) * 6
            onOpenRequested: {
                openEditorFile(contextDialog.currentPath)
                contextDialog.hide()
            }
        }

        Component {
            id: createProjectDialogComponent
            Dialog {
                title: qsTr("Create project:");
                modal: true
                anchors.centerIn: parent
                standardButtons: Dialog.Ok | Dialog.Cancel
                Component.onCompleted: imFixer.setupImEventFilter(projectName)

                signal done()

                TextField {
                    id: projectName
                    width: parent.width
                    placeholderText: qsTr("Name:")
                    validator: RegularExpressionValidator {
                        regularExpression: /^[a-zA-Z0-9_.-]*$/
                    }
                }

                onAccepted: {
                    projectCreator.createProject(projectName.text)
                    done()
                }

                onRejected: {
                    done()
                }
            }
        }

        Component {
            id: newFileDialogComponent
            Dialog {
                title: qsTr("New file:");
                modal: true
                anchors.centerIn: parent
                standardButtons: Dialog.Ok | Dialog.Cancel
                Component.onCompleted: imFixer.setupImEventFilter(fileName)
                property string rootPath: ""

                signal done()

                TextField {
                    id: fileName
                    width: parent.width
                    placeholderText: qsTr("Name:")
                    validator: RegularExpressionValidator {
                        regularExpression: /^[a-zA-Z0-9_.-]*$/
                    }
                }

                onAccepted: {
                    fileIo.createFile(rootPath + "/" + fileName.text)
                    fileName.text = ""
                    done()
                }

                onRejected: {
                    fileName.text = ""
                    done()
                }
            }
        }

        Component {
            id: newDirectoryDialogComponent
            Dialog {
                title: qsTr("New directory:");
                modal: true
                anchors.centerIn: parent
                standardButtons: Dialog.Ok | Dialog.Cancel
                Component.onCompleted: imFixer.setupImEventFilter(directoryName)
                property string rootPath: ""

                signal done()

                TextField {
                    id: directoryName
                    width: parent.width
                    placeholderText: qsTr("Name:")
                    validator: RegularExpressionValidator {
                        regularExpression: /^[a-zA-Z0-9_.-]*$/
                    }
                }

                onAccepted: {
                    fileIo.createDirectory(rootPath + "/" + directoryName.text)
                    directoryName.text = ""
                    done()
                }

                onRejected: {
                    directoryName.text = ""
                    done()
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
}
