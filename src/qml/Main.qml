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

    property alias dbugger: dbugger

    readonly property int paddingSmall: 8
    readonly property int paddingMid: 12
    readonly property int paddingMedium: 16
    readonly property int roundedCornersRadiusSmall: 8
    readonly property int roundedCornersRadius: 16
    readonly property int roundedCornersRadiusMedium: 24
    readonly property int sideBarExpandedDefault: 324
    readonly property bool landscapeMode : width > height
    readonly property int sideBarWidth: landscapeMode ? Math.min(sideBarExpandedDefault, width) : width
    readonly property bool shouldAllowSidebar: (projectList.projects.length > 0 &&
                                                openFiles.files.length > 0)
    readonly property bool shouldAllowDebugArea: (dbugger.running && wasmRunner.running) ||
                                                 dbugger.breakpoints.length > 0
    readonly property bool padStatusBar : true
    readonly property int headerItemHeight : 48
    readonly property int topBarHeight : 72
    readonly property int menuItemIconSize : 24

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
        projectBuilder.build(debugRequested, !releaseRequested && settings.aotOptimizations)
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

    function stopRunAndDebug() {
        debugRequested = false
        runRequested = false
        releaseRequested = false

        if (dbugger.running)
            dbugger.killDebugger()
        if (wasmRunner.running)
            wasmRunner.kill()
        if (projectBuilder.building)
            projectBuilder.cancel()
    }

    function toggleSettingsDialog() {
        if (settingsDialog.visibility) {
            settingsDialog.hide()
        } else {
            settingsDialog.show()
        }
    }

    function toggleHelpDialog() {
        if (helpDialog.visibility) {
            helpDialog.hide()
        } else {
            helpDialog.show()
        }
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
        if (width < height || shouldAllowDebugArea) {
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
                    enabled: !sysrootManager.installing
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
                            id: settingsButton
                            icon.source: Qt.resolvedUrl("qrc:/assets/gearshape.fill@2x.png")
                            text: qsTr("Settings")

                            onClicked: {
                                root.toggleSettingsDialog()
                            }
                        }

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
                                root.attemptBuild()
                            }
                        }

                        MenuItem {
                            id: helpButton
                            icon.source: Qt.resolvedUrl("qrc:/assets/questionmark.circle.fill@2x.png")
                            text: qsTr("Help")

                            onClicked: {
                                root.toggleHelpDialog()
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
                    text: compiling ?
                              qsTr("Building project...") :
                              delayedDebugContinue.running ? qsTr("Heating up for debugging...") :
                                                             ""
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
                    visible: projectBuilder.projectFile !== ""

                    onClicked: debugContextMenu.open()
                    onPressAndHold: debugContextMenu.open()

                    TideMenu {
                        id: debugContextMenu
                        MenuItem {
                            text: !showDebugArea ?
                                      qsTr("Show debugger") :
                                      qsTr("Hide debugger")
                            onTriggered: {
                                showDebugArea = !showDebugArea
                            }
                        }
                        MenuItem {
                            enabled: dbugger.running
                            text: dbugger.paused ? qsTr("Continue") : qsTr("Interrupt")
                            onTriggered: {
                                if (dbugger.paused) {
                                    dbugger.cont()
                                    consoleView.show()
                                } else {
                                    dbugger.pause()
                                }
                            }
                        }
                    }
                }

                TideToolButton {
                    rightPadding: paddingMedium

                    readonly property bool idle: !projectBuilder.building && !wasmRunner.running && !dbugger.running

                    icon.source: idle ?
                                     Qt.resolvedUrl("qrc:/assets/play.fill@2x.png") :
                                     Qt.resolvedUrl("qrc:/assets/stop.fill@2x.png")
                    icon.color: root.palette.button
                    visible: projectBuilder.projectFile !== ""

                    BusyIndicator {
                        visible: wasmRunner.running || projectBuilder.building || dbugger.running
                        running: wasmRunner.running || projectBuilder.building || dbugger.running
                        anchors.centerIn: parent
                    }

                    onClicked: {
                        if (idle) {
                            buildContextMenu.open()
                        } else {
                            root.stopRunAndDebug()
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
                                if (!isRunning) {
                                    root.debugRequested = false
                                    root.runRequested = true
                                    root.attemptBuild()
                                } else {
                                    root.stopRunAndDebug()
                                }
                            }
                        }
                        MenuItem {
                            property bool visibility: openFiles.files.length > 0 && projectBuilder.projectFile !== ""
                            enabled: !projectBuilder.building && !dbugger.running && visibility
                            text: qsTr("Debug")
                            icon.source: Qt.resolvedUrl("qrc:/assets/ladybug.fill@2x.png")

                            BusyIndicator {
                                visible: wasmRunner.running
                                running: wasmRunner.running
                                anchors.centerIn: parent
                            }

                            onClicked: {
                                root.debugRequested = true
                                root.runRequested = false
                                root.attemptBuild()
                            }
                        }
                    }
                }

                TideToolButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/terminal.fill@2x.png")
                    icon.color: root.palette.button
                    rightPadding: paddingMedium
                    enabled: !sysrootManager.installing

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
                runRequested = false
                debugRequested = false
                warningSign.flashWarning(qsTr("Build failed!"))
            }
        onBuildSuccess:
            (debug) => {
                compiling = false
                warningSign.flashSuccess(qsTr("Build successful!"))

                if (debug) {
                    root.attemptDebug()
                    debugRequested = false
                } else if (runRequested) {
                    root.attemptRun()
                    runRequested = false
                }

                if (releaseRequested) {
                    releaseRequested = false
                    const coords = contextButton.mapToGlobal(0, 0)
                    const pos = Qt.rect(coords.x, coords.y, contextButton.width, contextButton.height)
                    iosSystem.share("", "file://" + projectBuilder.runnableFile(), pos)
                }
            }
    }

    WasmRunner {
        id: wasmRunner
        system: iosSystem
        onRunningChanged: {
            if (running && settings.clearConsole)
                clearConsoleOutput()
        }

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
            showDebugArea = shouldAllowDebugArea;
            if (running) {
                dbugger.clearBacktrace();
                dbugger.clearFrameValues();
            }
            if (running && settings.clearConsole)
                clearConsoleOutput()
        }
        onProcessPaused: {
            dbugger.getBacktraceAndFrameValues()
        }
        onAttachedToProcess: {
            delayedDebugContinue.start()
        }
    }

    Timer {
        id: delayedDebugContinue
        repeat: false
        interval: 1000
        onTriggered: dbugger.cont()
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
        width: parent.width
        height: parent.height - (oskReactor.oskVisible ? oskReactor.oskHeight : 0)

        Behavior on height {
            NumberAnimation {
                easing.type: Easing.OutCubic
                duration: 300
            }
        }

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
            spacing: 1
            visible: projectList.projects.length > 0
            onVisibleChanged: mainView.forceLayout()

            x: !centered ? 0 : ((parent.width - width) / 2)
            y: !centered ? 0 : ((parent.height - height) / 2)
            width: !centered ? parent.width : dialogWidth
            height: !centered ? parent.height : dialogHeight

            readonly property bool centered : editor.invalidated
            Behavior on x {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic; }
            }
            Behavior on y {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic; }
            }
            Behavior on width {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic; }
            }
            Behavior on height {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic; }
            }

            readonly property int dialogWidth: parent.width <= sideBarWidth ?
                                                   sideBarWidth :
                                                   ((parent.width / 8) * 6)
            readonly property int dialogHeight: width === sideBarWidth ?
                                                    parent.height :
                                                    ((parent.height / 8) * 6)

            readonly property int settingsDialogWidth: parent.width <= sideBarWidth ?
                                                           sideBarWidth :
                                                           (parent.width / 2)
            readonly property int settingsDialogHeight: width === sideBarWidth ?
                                                            parent.height :
                                                            (parent.height / 2)

            Item {
                id: leftSideBar
                readonly property int rightPadding: showLeftSideBar && sideBarWidth == root.width ? paddingMedium : 0
                y: rightPadding
                width: showLeftSideBar ? sideBarWidth - rightPadding : 0
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

                Item {
                    x: paddingMedium
                    y: paddingMedium
                    width: parent.width - paddingMedium
                    height: parent.height - (paddingMedium * 2)
                    readonly property int spaceBetweenSections : openFiles.files.length > 0 ? paddingSmall : 0

                    Column {
                        width: parent.width
                        height: parent.height
                        spacing: parent.spaceBetweenSections

                        Item {
                            y: paddingSmall
                            width: parent.width
                            height: parent.height - openFilesArea.height - paddingMedium

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
                                        color: root.tidePalette.base
                                        clip: true

                                        ListView {
                                            headerPositioning: ListView.PullBackHeader
                                            header: Item {
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
                                                color: "transparent"
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

                        Item {
                            id: openFilesArea
                            property bool showArea : true
                            readonly property int usualHeight: (parent.height  - paddingMedium) / 2

                            opacity: !mainView.centered ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                            }

                            width: parent.width
                            height: openFiles.files.length > 0 ?
                                        (showArea ? openFilesArea.usualHeight : root.headerItemHeight) : 0

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
                                                    for (let i = dbugger.breakpoints.length - 1; i >= 0; i--) {
                                                        dbugger.removeBreakpoint(dbugger.breakpoints[i])
                                                    }
                                                    showDebugArea = false
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
                id: editorContainer
                width: parent.width - leftSideBar.width - debuggerArea.width
                height: parent.height - (openFiles.files.length > 0 ? 0 : paddingSmall)
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
                        attemptBuild();
                    }
                    onRunRequested: {
                        root.runRequested = true
                        attemptBuild();
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
            width: parent.width
            height: parent.height
            color: "black"
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

        /* Debugger area */
        Item {
            id: debuggerArea
            width: showDebugArea ? sideBarWidth - (paddingSmall) : 0
            anchors.topMargin: paddingMedium
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: paddingSmall
            anchors.leftMargin: paddingSmall
            anchors.bottomMargin: paddingMedium + paddingSmall
            visible: width > 0
            z: consoleView.z + 1

            readonly property int usableHeight : debuggerArea.height

            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Column {
                anchors.fill: parent
                clip: true
                spacing: paddingSmall

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: paddingSmall
                    anchors.leftMargin: paddingSmall
                    height: (debuggerArea.usableHeight / 3) - paddingSmall
                    radius: roundedCornersRadiusMedium
                    color: root.palette.base

                    ListView {
                        anchors.fill: parent
                        anchors.margins: paddingSmall
                        clip: true
                        model: dbugger.breakpoints
                        header: Item {
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
                                    enabled: dbugger.running
                                    font.pixelSize: 16
                                    onClicked: dbugger.stepIn()
                                }
                                ToolButton {
                                    Layout.alignment: Qt.AlignLeft
                                    Layout.leftMargin: paddingMedium
                                    icon.source: ""; // Qt.resolvedUrl("qrc:/assets/chevron.compact.up@2x.png")
                                    icon.width: 24
                                    icon.height: 24
                                    text: qsTr("Step out")
                                    enabled: dbugger.running
                                    font.pixelSize: 16
                                    onClicked: dbugger.stepOut()
                                }
                                ToolButton {
                                    Layout.alignment: Qt.AlignLeft
                                    Layout.rightMargin: paddingMedium
                                    icon.source: ""; // Qt.resolvedUrl("qrc:/assets/chevron.compact.up@2x.png")
                                    icon.width: 24
                                    icon.height: 24
                                    text: qsTr("Step over")
                                    enabled: dbugger.running
                                    font.pixelSize: 16
                                    onClicked: dbugger.stepOver()
                                }
                            }
                        }
                        delegate: TideButton {
                            icon.source: Qt.resolvedUrl("qrc:/assets/circle.fill@2x.png")
                            icon.color: "red"
                            text: modelData
                            width: parent.width
                            height: headerItemHeight
                            font.pixelSize: 18
                            color: root.palette.button
                            onClicked: breakpointContextMenu.open()

                            TideMenu {
                                id: breakpointContextMenu
                                MenuItem {
                                    text: qsTr("Delete breakpoint")
                                    onClicked: {
                                        dbugger.removeBreakpoint(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: paddingSmall
                    anchors.leftMargin: paddingSmall
                    height: (debuggerArea.usableHeight / 3) - paddingSmall
                    radius: roundedCornersRadiusMedium
                    color: root.palette.base

                    ListView {
                        id: backtracesListView
                        anchors.fill: parent
                        anchors.margins: paddingSmall
                        model: dbugger.backtrace
                        clip: true
                        spacing: paddingSmall
                        header: TideButton {
                            font.pixelSize: 18
                            text: qsTr("Callstack & frames:")
                            height: headerItemHeight
                            color: root.palette.button
                            /*onClicked: {
                                dbugger.getBacktrace();
                            }*/
                        }
                        delegate: DebuggerListEntry {
                            readonly property var dbugger: root.dbugger
                            readonly property bool frameIndex: modelData.frameIndex

                            radius: roundedCornersRadiusSmall
                            text: modelData.value
                            detailText: modelData.file === undefined || modelData.file === "" ?
                                            qsTr("Unknown file") :
                                            modelData.file + ":" + modelData.line
                            font.pixelSize: 18
                            width: backtracesListView.width
                            height: paddingSmall +
                                    Math.max(label.height, boldLabel.height) +
                                    paddingSmall +
                                    detailControl.font.pixelSize +
                                    paddingSmall
                            color: modelData.currentFrame ?
                                       root.palette.active.button :
                                       "transparent"
                            textColor: modelData.currentFrame ?
                                           root.palette.buttonText :
                                           root.palette.button
                            label.wrapMode: Label.WrapAtWordBoundaryOrAnywhere
                            outline: true
                            outlineColor: root.palette.button
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: paddingSmall
                    anchors.leftMargin: paddingSmall
                    height: (debuggerArea.usableHeight / 3) - paddingSmall
                    radius: roundedCornersRadiusMedium
                    color: root.palette.base

                    ListView {
                        id: frameValuesListView
                        anchors.fill: parent
                        anchors.margins: paddingSmall
                        model: dbugger.values
                        spacing: paddingSmall
                        clip: true
                        header: TideButton {
                            font.pixelSize: 18
                            text: qsTr("Values & instructions:")
                            color: root.palette.button
                            height: headerItemHeight
                            onClicked: {
                                dbugger.getFrameValues();
                            }
                        }
                        delegate: DebuggerListEntry {
                            id: valueOrInstruction
                            boldText: modelData.partial || modelData.name === undefined ?
                                          "" :
                                          modelData.type
                            text: modelData.partial || modelData.name === undefined ?
                                      modelData.value :
                                      modelData.name
                            detailText: modelData.partial || modelData.name === undefined ?
                                            "" :
                                            modelData.value
                            font.pixelSize: 18
                            width: frameValuesListView.width
                            height: paddingSmall +
                                    label.font.pixelSize +
                                    paddingSmall +
                                    detailControl.font.pixelSize +
                                    paddingSmall
                            outline: true
                            outlineColor: root.palette.button
                            textColor: root.palette.button
                            radius: roundedCornersRadiusSmall

                            property bool showToolTip : false
                            onClicked: {
                                showToolTip = true
                            }
                            onPressedChanged: {
                                if (!pressed) {
                                    showToolTip = false;
                                }
                            }

                            ToolTip {
                                visible: valueOrInstruction.showToolTip
                                text: modelData.value
                                width: valueOrInstruction.width
                                x: (valueOrInstruction.width - width) / 2
                                y: ((valueOrInstruction.height) / 2) - height
                            }
                        }
                    }
                }
            }
        }

        SettingsDialog {
            id: settingsDialog
            width: mainView.settingsDialogWidth
            height: mainView.settingsDialogHeight
            anchors.centerIn: parent
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
            property bool clearConsole: true
            property bool aotOptimizations : false
        }

        ConsoleView {
            id: consoleView
            width: !landscapeMode && showDebugArea ?
                       0 : // Don't overlap debugger area and ConsoleView in portraitMode
                       mainView.dialogWidth - (debuggerArea.width / 2)
            height: mainView.dialogHeight
        }

        ContextView {
            id: contextDialog
            width: !landscapeMode && showDebugArea ?
                    0 : // Don't overlap debugger area and ConsoleView in portraitMode
                    mainView.dialogWidth - (debuggerArea.width / 2)
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

        // Loading splash screen
        Rectangle {
            property bool visibility: sysrootManager.installing
            anchors.fill: parent
            visible: opacity > 0.0
            color: "black"
            opacity: visibility ? 0.85 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Label {
                id: preparationHint
                anchors.centerIn: parent
                width: parent.width - (paddingSmall * 2)
                font.pixelSize: 30
                text: qsTr("Preparing environment, hold on...")
                color: "white"
                wrapMode: Label.WrapAtWordBoundaryOrAnywhere
                horizontalAlignment: Qt.AlignHCenter
            }

            ProgressBar {
                id: preparationProgressBar
                clip: true
                anchors.top: preparationHint.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: paddingSmall
                anchors.leftMargin: parent.width / 4
                anchors.rightMargin: parent.width / 4
                value: sysrootManager.progress
                onValueChanged: {
                    preparationProgressBar.indeterminate = false
                    indeterminateTimer.start()
                }
            }

            Timer {
                id: indeterminateTimer
                interval: 1000
                repeat: false
                onTriggered: {
                    preparationProgressBar.indeterminate = true
                }
            }

            MouseArea {
                anchors.fill: parent
            }
        }
    }
}
