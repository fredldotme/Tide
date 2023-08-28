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

    SystemPalette { id: tidePalette; colorGroup: SystemPalette.Active }
    property alias tidePalette : tidePalette

    readonly property int paddingSmall: 8
    readonly property int paddingMid: 12
    readonly property int paddingMedium: 16
    readonly property int roundedCornersRadiusSmall: 8
    readonly property int roundedCornersRadius: 16
    readonly property int roundedCornersRadiusMedium: 24
    readonly property int sideBarExpandedDefault: 324
    readonly property int sideBarWidth: width > height ? Math.min(sideBarExpandedDefault, width) : width
    readonly property bool shouldAllowSidebar: (projectList.projects.length > 0 &&
                                                openFiles.files.length > 0)
    readonly property bool shouldAllowDebugArea: dbugger.runner && wasmRunner.running
    readonly property bool padStatusBar : true
    readonly property int headerItemHeight : 48
    readonly property int topBarHeight : 72

    property font fixedFont: standardFixedFont
    property bool showLeftSideBar: true
    property bool showDebugArea: false
    property bool compiling: false

    property bool releaseRequested : false
    property bool runRequested : false
    property bool debugRequested : false

    signal fileSaved()

    function saveCurrentFile() {
        if (editor.file == null || editor.invalidated)
            return

        const file = editor.file
        const path = projectPicker.openBookmark(file.bookmark)
        editor.loading = true
        fileIo.writeFile(file.path, editor.text)
        editor.loading = false
        editor.changed = false
        projectPicker.closeFile(path);
        editor.reloadAst()

        fileSaved()
    }

    function clearConsoleOutput() {
        consoleView.consoleOutput.clear()
    }

    function attemptBuild() {
        if (editor.invalidated)
            return;

        saveCurrentFile()
        root.compiling = true
        projectBuilder.clean()
        projectBuilder.build(debugRequested)
    }

    function attemptRun() {
        if (editor.invalidated)
            return;

        const killOnly = wasmRunner.running

        wasmRunner.kill();
        if (killOnly)
            return;

        consoleView.show()
        wasmRunner.run(projectBuilder.runnableFile(), [])
    }

    function attemptDebug() {
        if (editor.invalidated)
            return;

        const killOnly = wasmRunner.running

        wasmRunner.kill();
        if (killOnly)
            return;

        consoleView.show()
        showDebugArea = true
        dbugger.debug(projectBuilder.runnableFile(), [])
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
        if (width < height && shouldAllowSidebar) {
            showLeftSideBar = false
        } else {
            showLeftSideBar = true
        }

        // Hide the debug area on small screens
        if (width < height && shouldAllowDebugArea) {
            showDebugArea = false;
        } else {
            showDebugArea = shouldAllowDebugArea;
        }
    }

    header: Pane {
        topPadding: padStatusBar ? oskReactor.statusBarHeight : 0
        width: parent.width
        height: topBarHeight

        Column {
            anchors.fill: parent
            spacing: paddingSmall * 2

            RowLayout {
                spacing: paddingMid
                width: parent.width
                height: root.headerItemHeight

                TideToolButton {
                    id: contextButton
                    icon.source: Qt.resolvedUrl("qrc:/assets/ellipsis.circle@2x.png")
                    icon.color: root.palette.button
                    leftPadding: paddingMedium

                    function wiggle() {
                        if (!settings.wiggleHints)
                            return
                        contextButtonWiggleAnimation.restart()
                    }

                    SequentialAnimation {
                        id: contextButtonWiggleAnimation

                        NumberAnimation {
                            target: contextButton
                            property: "rotation"
                            duration: 100
                            from: 0
                            to: -45
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: contextButton
                            property: "rotation"
                            duration: 200
                            from: -45
                            to: 45
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: contextButton
                            property: "rotation"
                            duration: 100
                            from: 45
                            to: 0
                            easing.type: Easing.Linear
                        }
                    }

                    TideMenu {
                        id: contextMenu
                        MenuItem {
                            id: contextFieldSearchButton
                            text: qsTr("Find && replace")
                            icon.source: Qt.resolvedUrl("qrc:/assets/magnifyingglass.circle.fill@2x.png")
                            readonly property bool visibility : !editor.invalidated
                            enabled: visibility
                            visible: visibility
                            height: visible ? implicitHeight : 0
                            onVisibilityChanged: contextButton.wiggle()

                            onClicked: {
                                let root = editor.file.path
                                if (contextDialog.visibility)
                                    contextDialog.hide()
                                else
                                    contextDialog.show(root)
                            }
                        }

                        MenuItem {
                            text: qsTr("Autocomplete")
                            icon.source: Qt.resolvedUrl("qrc:/assets/keyboard.badge.eye@2x.png")
                            readonly property bool visibility : editor.canUseAutocomplete
                            enabled: visibility
                            visible: visibility
                            height: visible ? implicitHeight : 0
                            onVisibilityChanged: contextButton.wiggle()

                            onClicked: {
                                editor.autocomplete()
                            }
                        }

                        MenuItem {
                            id: formatButton
                            text: qsTr("Autoformat")
                            icon.source: Qt.resolvedUrl("qrc:/assets/line.3.horizontal.circle.fill@2x.png")
                            readonly property bool visibility : editor.canUseAutoformat
                            enabled: visibility
                            visible: visibility
                            height: visible ? implicitHeight : 0
                            onVisibilityChanged: contextButton.wiggle()

                            onClicked: {
                                editor.format()
                            }
                        }

                        MenuItem {
                            id: releaseButton
                            text: qsTr("Release")
                            icon.source: Qt.resolvedUrl("qrc:/assets/briefcase.circle.fill@2x.png")
                            readonly property bool visibility : projectBuilder.projectFile !== ""
                            visible: visibility
                            enabled: visibility
                            height: visible ? implicitHeight : 0
                            onVisibilityChanged: contextButton.wiggle()

                            onClicked: {
                                releaseRequested = true
                                projectBuilder.clean()
                                projectBuilder.build(false)
                            }
                        }

                        MenuItem {
                            id: helpButton
                            icon.source: Qt.resolvedUrl("qrc:/assets/questionmark.circle.fill@2x.png")
                            text: qsTr("Help")

                            onClicked: {
                                if (helpDialog.visibility) {
                                    helpDialog.hide()
                                } else {
                                    helpDialog.show()
                                }
                            }
                        }

                        MenuItem {
                            id: settingsButton
                            icon.source: Qt.resolvedUrl("qrc:/assets/gearshape.fill@2x.png")
                            text: qsTr("Settings")

                            onClicked: {
                                if (settingsDialog.visibility) {
                                    settingsDialog.hide()
                                } else {
                                    settingsDialog.show()
                                }
                            }
                        }
                    }

                    onClicked: {
                        if (!contextMenu.visible)
                            contextMenu.open()
                        else
                            contextMenu.close()
                    }
                }

                TideToolButton {
                    id: sideBarButton
                    icon.source: Qt.resolvedUrl("qrc:/assets/sidebar.left@2x.png")
                    icon.color: root.palette.button
                    visible: shouldAllowSidebar
                    onClicked: showLeftSideBar = !showLeftSideBar
                }

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    color: root.palette.button
                    text: compiling ? qsTr("Building project...") : ""
                    elide: Text.ElideRight
                    font.bold: true
                    horizontalAlignment: Label.AlignHCenter
                    verticalAlignment: Label.AlignVCenter
                }

                /*
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
                    rightPadding: paddingMedium
                    icon.source: Qt.resolvedUrl("qrc:/assets/ladybug.fill@2x.png")
                    icon.color: root.palette.button
                    visible: true

                    onClicked: showDebugArea = !showDebugArea
                    onPressAndHold: debugContextMenu.open()

                    TideMenu {
                        id: debugContextMenu
                        MenuItem {
                            text: qsTr("Interrupt")
                            onTriggered: {
                                dbugger.pause()
                            }
                        }
                        MenuItem {
                            text: qsTr("Continue")
                            onTriggered: {
                                dbugger.cont()
                            }
                        }
                        MenuItem {
                            text: qsTr("Step into")
                            onTriggered: {
                                dbugger.stepInto()
                            }
                        }
                        MenuItem {
                            text: qsTr("Step out")
                            onTriggered: {
                                dbugger.stepOut()
                            }
                        }
                        MenuItem {
                            text: qsTr("Step over")
                            onTriggered: {
                                dbugger.stepOver()
                            }
                        }
                    }
                }

                TideToolButton {
                    rightPadding: paddingMedium
                    icon.source: !wasmRunner.running && !projectBuilder.building ?
                                     Qt.resolvedUrl("qrc:/assets/play.fill@2x.png") :
                                     Qt.resolvedUrl("qrc:/assets/stop.fill@2x.png")
                    icon.color: root.palette.button
                    visible: projectBuilder.projectFile !== ""

                    BusyIndicator {
                        visible: wasmRunner.running || projectBuilder.building
                        running: wasmRunner.running || projectBuilder.building
                        anchors.centerIn: parent
                    }

                    onClicked: {
                        if (!projectBuilder.building && !wasmRunner.running) {
                            root.runRequested = true
                            root.attemptBuild()
                        } else if (wasmRunner.running || projectBuilder.building) {
                            runRequested = false
                            releaseRequested = false
                            if (dbugger.running)
                                dbugger.quitDebugger()
                            if (wasmRunner.running)
                                wasmRunner.kill()
                            if (projectBuilder.building)
                                projectBuilder.cancel()
                        }
                    }
                    onPressAndHold: {
                        buildContextMenu.open()
                    }

                    TideMenu {
                        id: buildContextMenu
                        MenuItem {
                            text: qsTr("Clean")
                            icon.source: Qt.resolvedUrl("qrc:/assets/trash.fill@2x.png")
                            enabled: !projectBuilder.building && !wasmRunner.running && projectBuilder.projectFile !== ""
                            onTriggered: {
                                projectBuilder.clean()
                            }
                        }
                        MenuItem {
                            text: qsTr("Build")
                            icon.source: Qt.resolvedUrl("qrc:/assets/hammer.fill@2x.png")
                            enabled: !projectBuilder.building && !wasmRunner.running && projectBuilder.projectFile !== ""
                            onTriggered: {
                                root.debugRequested = false
                                root.runRequested = false
                                root.attemptBuild()
                            }
                        }
                        MenuItem {
                            property bool isRunning: wasmRunner.running
                            text: !isRunning ? qsTr("Run") : qsTr("Stop")
                            icon.source: !isRunning ?
                                             Qt.resolvedUrl("qrc:/assets/play.fill@2x.png") :
                                             Qt.resolvedUrl("qrc:/assets/stop.fill@2x.png")
                            enabled: !projectBuilder.building && projectBuilder.projectFile !== ""
                            onTriggered: {
                                root.attemptRun()
                            }
                        }
                        MenuItem {
                            property bool visibility: openFiles.files.length > 0 && projectBuilder.projectFile !== ""
                            enabled: !projectBuilder.building && visibility
                            text: qsTr("Debug")
                            icon.source: Qt.resolvedUrl("qrc:/assets/ladybug.fill@2x.png")

                            BusyIndicator {
                                visible: wasmRunner.running
                                running: wasmRunner.running
                                anchors.centerIn: parent
                            }

                            onClicked: {
                                root.debugRequested = true
                                root.runRequested = true
                                root.attemptBuild()
                            }
                        }
                    }
                }

                /*
                TideToolButton {
                    visible: openFiles.files.length > 0 && projectBuilder.projectFile !== ""
                    enabled: !projectBuilder.building
                    icon.source: !wasmRunner.running ?
                                     Qt.resolvedUrl("qrc:/assets/ladybug.fill@2x.png") :
                                     Qt.resolvedUrl("qrc:/assets/stop.fill@2x.png")
                    icon.color: root.palette.button

                    BusyIndicator {
                        visible: wasmRunner.running
                        running: wasmRunner.running
                        anchors.centerIn: parent
                    }

                    onClicked: {
                        root.attemptDebug()
                    }
                }
                */

                TideToolButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/terminal.fill@2x.png")
                    icon.color: root.palette.button
                    rightPadding: paddingMedium

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

            if (runRequested) {
                runRequested = false

                if (debugRequested) {
                    debugRequested = false
                    root.attemptDebug()
                } else {
                    root.attemptRun()
                }
            }

            if (releaseRequested) {
                releaseRequested = false
                Qt.openUrlExternally("shareddocuments://" + projectBuilder.runnableFile())
            }
        }
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

    Debugger {
        id: dbugger
        runner: wasmRunner
        system: iosSystem
        onRunningChanged: {
            if (!running) {
                showDebugArea = false;
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
        anchors.rightMargin: debuggerArea.width

        Component.onCompleted: {
            oskReactor.item = mainContainer
        }

        ColumnLayout {
            id: startPage
            anchors.centerIn: parent
            width: parent.width
            spacing: paddingMedium
            visible: projectList.projects.length === 0

            readonly property int sideLength : 32

            Image {
                Layout.alignment: Qt.AlignHCenter
                source: Qt.resolvedUrl("qrc:/assets/TideNaked@2x.png")
                Layout.preferredWidth: Math.min(128, parent.width)
                Layout.preferredHeight: width
            }

            Text {
                Layout.preferredWidth: parent.width
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                font.pixelSize: startPage.sideLength
                color: root.palette.text
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
                        let createProjectDialog = createProjectDialogComponent.createObject(mainContainer)
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

            Row {
                width: parent.width
                spacing: paddingMedium
                Layout.alignment: Qt.AlignHCenter

                TideButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/questionmark.circle.fill@2x.png")
                    icon.width: startPage.sideLength
                    icon.height: startPage.sideLength
                    font.pixelSize: startPage.sideLength
                    height: startPage.sideLength
                    color: root.palette.button
                    text: qsTr("Help")
                    onClicked: helpDialog.show()
                }
            }
        }

        Row {
            id: mainView
            anchors.fill: parent
            spacing: 1
            visible: projectList.projects.length > 0
            onVisibleChanged: mainView.forceLayout()

            readonly property int dialogWidth: parent.width <= sideBarWidth ?
                                                   sideBarWidth :
                                                   ((parent.width / 8) * 6)
            readonly property int dialogHeight: width === sideBarWidth ?
                                                    parent.height :
                                                    ((parent.height / 8) * 6)

            Pane {
                id: leftSideBar
                width: showLeftSideBar ? sideBarWidth : 0
                height: parent.height
                clip: true
                topInset: 0
                bottomInset: 0
                topPadding: 0
                leftPadding: 0
                rightPadding: showLeftSideBar && sideBarWidth == root.width ? paddingMedium : 0
                rightInset: showLeftSideBar ? 0 : paddingMedium

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
                    topInset: 0
                    leftInset: 0
                    rightInset: 0
                    bottomInset: 0
                    topPadding: paddingMedium
                    bottomPadding: paddingMedium
                    rightPadding: 0

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

                            // TODO: Maybe keep for other purposes?
                        }

                        Column {
                            y: paddingSmall
                            width: parent.width
                            anchors {
                                top: contextField.bottom
                                bottom: openFilesArea.top
                                bottomMargin: openFilesArea.height > 0 ? paddingSmall : 0
                            }

                            Behavior on height {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }

                            StackView {
                                id: projectNavigationStack
                                width: parent.width
                                height: parent.height
                                clip: true
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
                                            header: Rectangle {
                                                clip: true
                                                width: projectNavigationStack.width
                                                height: root.headerItemHeight
                                                color: root.tidePalette.base
                                                radius: roundedCornersRadiusMedium
                                                RowLayout {
                                                    anchors.fill: parent
                                                    spacing: paddingSmall * 2
                                                    ToolButton {
                                                        text: qsTr("Create")
                                                        icon.source: Qt.resolvedUrl("qrc:/assets/plus.app@2x.png")
                                                        icon.color: root.palette.button
                                                        leftPadding: paddingMedium
                                                        onClicked: {
                                                            let createProjectDialog = createProjectDialogComponent.createObject(mainContainer)
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
                                                font.pixelSize: 16
                                                height: font.pixelSize + (paddingSmall * 2)
                                                textColor: root.palette.button
                                                icon.source: modelData.isBookmark ?
                                                                 Qt.resolvedUrl("qrc:/assets/bookmark@2x.png") :
                                                                 Qt.resolvedUrl("qrc:/assets/folder@2x.png")

                                                anchors {
                                                    left: parent.left
                                                    leftMargin: paddingMedium
                                                    right: parent.right
                                                    rightMargin: paddingMedium
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
                                                TideMenu {
                                                    id: projectsContextMenu
                                                    property var selectedProject: null

                                                    MenuItem {
                                                        text: qsTr("Open in Files app")
                                                        icon.source: Qt.resolvedUrl("qrc:/assets/folder@2x.png")
                                                        onClicked: {
                                                            Qt.openUrlExternally("shareddocuments://" + projectsContextMenu.selectedProject.path)
                                                        }
                                                    }

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
                                            clip: true
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
                                            header: Rectangle {
                                                width: projectNavigationStack.width
                                                height: root.headerItemHeight
                                                clip: true
                                                color: root.tidePalette.base
                                                radius: roundedCornersRadiusMedium
                                                RowLayout {
                                                    anchors.fill: parent
                                                    spacing: paddingSmall * 2
                                                    TideToolButton {
                                                        text: qsTr("New file")
                                                        icon.source: Qt.resolvedUrl("qrc:/assets/doc.badge.plus@2x.png")
                                                        icon.color: root.palette.button
                                                        leftPadding: paddingMedium
                                                        onClicked: {
                                                            let newFileDialog = newFileDialogComponent.createObject(mainContainer)
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
                                                            let newDirectoryDialog = newDirectoryDialogComponent.createObject(mainContainer)
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
                                                    rightMargin: paddingMedium
                                                }

                                                font.pixelSize: 16
                                                height: font.pixelSize + detailControl.font.pixelSize + (paddingSmall * 2)

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

                                                TideMenu {
                                                    id: directoryListViewContextMenu
                                                    readonly property bool isDir : (modelData.type === DirectoryListing.Directory)

                                                    MenuItem {
                                                        text: qsTr("Share")
                                                        icon.source: Qt.resolvedUrl("qrc:/assets/square.and.arrow.up@2x.png")
                                                        onClicked: {
                                                            const coords = fileListingButton.mapToGlobal(0, 0)
                                                            const pos = Qt.rect(coords.x, coords.y, width, height)
                                                            iosSystem.share("", "file://" + modelData.path, pos)
                                                        }
                                                    }

                                                    MenuItem {
                                                        text: qsTr("Open in Files app")
                                                        icon.source: Qt.resolvedUrl("qrc:/assets/folder@2x.png")
                                                        onClicked: {
                                                            Qt.openUrlExternally("shareddocuments://" + modelData.path)
                                                        }
                                                    }

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
                            property bool showArea : true
                            readonly property int usualHeight: (parent.height / 2) - (contextField.height / 2) - (paddingMedium / 2)


                            width: parent.width
                            height: openFiles.files.length > 0 ?
                                        (showArea ? openFilesArea.usualHeight : root.headerItemHeight) : 0
                            anchors.bottom: parent.bottom

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
                                            ToolButton {
                                                Layout.alignment: Qt.AlignLeft
                                                Layout.leftMargin: paddingMedium
                                                icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")
                                                icon.width: 24
                                                icon.height: 24
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
                                            ToolButton {
                                                Layout.alignment: Qt.AlignRight
                                                Layout.rightMargin: paddingMedium
                                                icon.source: openFilesArea.showArea ?
                                                                 Qt.resolvedUrl("qrc:/assets/chevron.compact.down@2x.png") :
                                                                 Qt.resolvedUrl("qrc:/assets/chevron.compact.up@2x.png")
                                                icon.width: 32
                                                icon.height: 32
                                                Layout.preferredWidth: 32
                                                Layout.preferredHeight: 32
                                                font.pixelSize: 16
                                                onClicked: {
                                                    openFilesArea.showArea = !openFilesArea.showArea
                                                }
                                            }
                                        }
                                    }

                                    clip: true
                                    delegate: OpenFileListingButton {
                                        readonly property bool isProject : modelData.name.endsWith(".pro") // || modelData.name.endsWith("CMakeLists.txt")
                                        readonly property bool isActiveProject: modelData.path === projectBuilder.projectFile
                                        radius: roundedCornersRadiusSmall

                                        function getDetailText() {
                                            let texts = []
                                            if (editor.file.path === modelData.path) {
                                                if (projectBuilder.projectFile === editor.file.path)
                                                    texts.push(qsTr("Active project"))
                                                if (editor.changed)
                                                    texts.push(qsTr("Unsaved"))
                                            }
                                            return texts.join(" | ")
                                        }

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
                                        detailText: getDetailText()
                                        height: font.pixelSize + detailControl.height + (paddingSmall * 2)
                                        font.pixelSize: 16
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
                                        TideMenu {
                                            id: openFilesContextMenu
                                            property var selectedFile: null

                                            MenuItem {
                                                text: qsTr("Close")
                                                icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")
                                                onClicked: {
                                                    let file = openFilesContextMenu.selectedFile
                                                    if (file.path === projectBuilder.projectFile)
                                                        projectBuilder.unloadProject()

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
                visible: projectList.projects.length > 0

                CodeEditor {
                    id: editor
                    anchors.fill: parent
                    anchors {
                        topMargin: paddingMedium
                        rightMargin: paddingMedium
                        leftMargin: showLeftSideBar ? paddingSmall : paddingMedium
                        bottomMargin: paddingMedium + paddingSmall
                    }

                    fileIo: fileIo
                    projectPicker: projectPicker
                    projectBuilder: projectBuilder
                    openFiles: openFiles
                    dbugger: dbugger
                    onSaveRequested: saveCurrentFile()
                    onFindRequested: contextDialog.show(editor.file.path)
                    onBuildRequested: {
                        projectBuilder.clean()
                        projectBuilder.build(false)
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
            width: mainView.dialogWidth
            height: mainView.dialogHeight
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
            property bool wiggleHints : true
            property bool wrapEditor : true
        }

        ConsoleView {
            id: consoleView
            width: mainView.dialogWidth
            height: mainView.dialogHeight
        }

        ContextView {
            id: contextDialog
            width: mainView.dialogWidth
            height: mainView.dialogHeight
            onOpenRequested: {
                openEditorFile(contextDialog.currentPath)
                contextDialog.hide()
            }
        }

        Component {
            id: createProjectDialogComponent
            TideDialog {
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
            TideDialog {
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
            TideDialog {
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

        TideInteractiveDialog {
            id: helpDialog
            width: mainView.dialogWidth
            height: mainView.dialogHeight
            ScrollView {
                anchors.fill: parent
                contentWidth: -1
                HelpPage {
                    width: parent.width
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: roundedCornersRadius
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
                warningText.color = "teal"
                flashingIcon.icon.color = "teal"
                opacity = 1.0
            }

            function flashWarning(text) {
                flashingIcon.icon.source = iconWarning
                warningText.text = text
                warningText.color = "darkred"
                flashingIcon.icon.color = "darkred"
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

    Rectangle {
        id: debuggerArea
        width: showDebugArea ? sideBarExpandedDefault : 0
        anchors.topMargin: paddingMedium
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: paddingSmall
        anchors.leftMargin: paddingSmall
        anchors.bottomMargin: paddingMedium + paddingSmall
        visible: width > 0
        radius: roundedCornersRadiusMedium
        color: root.palette.base

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Item {
            id: debuggerAreaToolbar
            width: projectNavigationStack.width
            height: root.headerItemHeight

            RowLayout {
                anchors.fill: parent
                spacing: paddingSmall * 2
                ToolButton {
                    Layout.alignment: Qt.AlignLeft
                    Layout.leftMargin: paddingMedium
                    icon.source: "" // Qt.resolvedUrl("qrc:/assets/xmark@2x.png")
                    icon.width: 24
                    icon.height: 24
                    text: qsTr("Step in")
                    font.pixelSize: 16
                    onClicked: dbugger.stepIn()
                }
                ToolButton {
                    Layout.alignment: Qt.AlignRight
                    Layout.rightMargin: paddingMedium
                    icon.source: ""; // Qt.resolvedUrl("qrc:/assets/chevron.compact.up@2x.png")
                    icon.width: 24
                    icon.height: 24
                    text: qsTr("Step out")
                    font.pixelSize: 16
                    onClicked: dbugger.stepOut()
                }
                ToolButton {
                    Layout.alignment: Qt.AlignRight
                    Layout.rightMargin: paddingMedium
                    icon.source: ""; // Qt.resolvedUrl("qrc:/assets/chevron.compact.up@2x.png")
                    icon.width: 24
                    icon.height: 24
                    text: qsTr("Step over")
                    font.pixelSize: 16
                    onClicked: dbugger.stepOver()
                }
            }
        }

        Column {
            anchors.top: debuggerAreaToolbar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            spacing: paddingSmall * 2

            ListView {
                anchors.left: parent.left
                anchors.leftMargin: paddingMedium
                anchors.right: parent.right
                height: (debuggerArea.height / 2) - paddingSmall
                model: dbugger.breakpoints
                header: Label {
                    font.pixelSize: 20
                    text: qsTr("Breakpoints")
                }
                delegate: TideButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/circle.fill@2x.png")
                    icon.color: "red"
                    text: modelData
                    font.pixelSize: 24
                    color: root.palette.button
                    onClicked: {
                        consoleView.hide()
                    }
                }
            }

            ListView {
                anchors.left: parent.left
                anchors.leftMargin: paddingMedium
                anchors.right: parent.right
                height: (debuggerArea.height / 2) - paddingSmall
                model: dbugger.values
                header: Label {
                    font.pixelSize: 20
                    text: qsTr("Values:")
                }
                delegate: Label {
                    text: modelData.name
                    font.pixelSize: 24
                    color: root.palette.button
                }
            }
        }
    }
}
