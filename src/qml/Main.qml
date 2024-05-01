import Qt.labs.settings
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import Tide

ApplicationWindow {
    id: root
    width: 1280
    height: 720
    visible: true
    title: qsTr("Tide")
    flags: Qt.Window | Qt.MaximizeUsingFullscreenGeometryHint
    background: Rectangle {
        color: mainBackgroundDefaultColor
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: mainBackgroundColor
            }
            GradientStop {
                position: (headerBarHeight * 3) / root.height
                color: Qt.tint(mainBackgroundColor, mainBackgroundDefaultColor)
            }
        }
    }

    onClosing:
        (event) => {
            Qt.quit();
        }

    SystemPalette { id: tidePalette; colorGroup: SystemPalette.Active }
    property alias tidePalette : tidePalette
    property alias dbugger: dbugger
    property alias openFiles: openFiles

    readonly property alias preview : editor.preview

    readonly property int paddingTiny: 4
    readonly property int paddingSmall: 6
    readonly property int paddingMid: 10
    readonly property int paddingMedium: 12
    readonly property int paddingLarge: 20
    readonly property int roundedCornersRadiusSmall: 8
    readonly property int roundedCornersRadius: 12
    readonly property int roundedCornersRadiusMedium: 18
    readonly property int sideBarStartWidth : (mainView.width / 2)
    readonly property int sideBarExpandedWidth : 300
    readonly property int sideBarExpandedDefault: openFiles.files.length === 0 ?
                                                      sideBarStartWidth : sideBarExpandedWidth
    readonly property bool landscapeMode : width > height
    readonly property int sideBarWidth: landscapeMode ? Math.min(sideBarExpandedDefault, width) : width
    readonly property bool shouldAllowSidebar: (projectList.projects.length > 0 &&
                                                openFiles.files.length > 0)
    readonly property bool shouldAllowDebugArea: ((dbugger.running || dbugger.paused) ||
                                                  (dbugger.waitingpoints.length > 0)) &&
                                                 (projectBuilder.projectFile !== "" && projectBuilder.isRunnable())
    readonly property bool padStatusBar : true
    readonly property int headerBarHeight : 48
    readonly property int headerItemHeight : 24
    readonly property int toolBarHeight : 40
    readonly property int menuItemIconSize : 20
    readonly property real defaultRectangleShadow: 0.2
    readonly property string dirOpenProtocol : Qt.platform.os === "ios" ?
                                                   "shareddocuments://" :
                                                   "file://"

    readonly property color borderColor : Qt.tint(mainBackgroundDefaultColor, "#10FF0000")
    property color headerItemColor : (dialogShadow.visible || mainBackgroundColorOverride !== mainBackgroundDefaultColor || wantContextColor) ?
                                         "white" : root.palette.button
    Behavior on headerItemColor {
        ColorAnimation {
            duration: 300
        }
    }
    readonly property color mainBackgroundDefaultColor : root.palette.window
    property color mainBackgroundColorOverride : root.palette.window
    Binding on mainBackgroundColorOverride {
        target: root
        property: "palette.window"
        value: root.palette.window
    }
    onMainBackgroundColorOverrideChanged: {
        mainBackgroundColorOverrideResetTimer.restart()
    }

    Timer {
        id: mainBackgroundColorOverrideResetTimer
        interval: 3000
        repeat: false
        onTriggered: mainBackgroundColorOverride = mainBackgroundDefaultColor
    }

    readonly property color tintedRunColor : {
        const col = Qt.color("teal")
        const alphaCol = Qt.rgba(col.r, col.g, col.b, 1.0)
        return Qt.tint(mainBackgroundDefaultColor, alphaCol)
    }
    readonly property color tintedDebugColor : {
        const col = Qt.color("darkorange")
        const alphaCol = Qt.rgba(col.r, col.g, col.b, 1.0)
        return Qt.tint(mainBackgroundDefaultColor, alphaCol)
    }

    readonly property bool wantContextColor : dbugger.running || runners.atLeastOneRunning
    readonly property color contextColor : dbugger.running ?
                                               tintedDebugColor :
                                               runners.atLeastOneRunning ?
                                                   tintedRunColor :
                                                   mainBackgroundDefaultColor
    property color mainBackgroundColor : (wantContextColor) ?
                                             contextColor : mainBackgroundColorOverride
    Behavior on mainBackgroundColor {
        ColorAnimation {
            duration: 300
        }
    }

    property font fixedFont: standardFixedFont
    property bool showLeftSideBar: true
    property bool showDebugArea: false
    property bool compiling: false

    property bool releaseRequested : false
    property bool runRequested : false
    property bool debugRequested : false
    property bool stopRequested : false

    signal fileSaved()

    function showDialog(dialogComponent) {
        let dialog = dialogComponent.createObject(paddedOverlayArea)
        dialog.done.connect(function() {
            dialog.destroy()
        })
        dialog.z = paddedOverlayArea.dialogZ
        dialog.open()
        return dialog
    }

    function saveCurrentFile() {
        if (editor.file == null || editor.invalidated)
            return

        const file = editor.file
        console.log("File to save: " + file.path);
        if (!fileIo.fileIsTextFile(file.path) || root.fileIsImageFile(file.path)) {
            hud.hudLabel.flashMessage(qsTr("Not saving binary file..."))
            console.log("Not saving binary file!");
            return
        }

        const path = projectPicker.openBookmark(file.bookmark)
        editor.loading = true
        fileIo.writeFile(file.path, editor.text)
        editor.loading = false
        editor.changed = false
        projectPicker.closeFile(path);

        // Refresh what's necessary
        editor.reloadAst()
        projectBuilder.reloadProperties();

        fileSaved()
    }

    function clearConsoleOutput() {
        consoleView.consoleOutput.clear()
    }

    function attemptBuild() {
        if (projectBuilder.building)
            return;

        if (editor.invalidated)
            return;

        if (projectBuilder.projectFile === "")
            return;

        saveCurrentFile()

        hud.hudLabel.flashMessage(qsTr("Building project..."))
        root.compiling = true
        
        if (settings.clearConsole)
            clearConsoleOutput()

        projectBuilder.clean()

        // No AOT for releases
        const aot = !releaseRequested && settings.optimizations
        projectBuilder.build(debugRequested, aot)
    }

    function attemptRun() {
        if (wasmRunner.running)
            return;

        if (editor.invalidated)
            return;

        if (!projectBuilder.isRunnable()) {
            hud.hudLabel.flashMessage(qsTr("Not a runnable project..."));
            return;
        }

        const killOnly = wasmRunner.running;

        wasmRunner.kill();
        if (killOnly)
            return;

        consoleView.show();
        wasmRunner.configure(settings.stackSize,
                             settings.heapSize,
                             settings.threads,
                             platformProperties.supportsOptimizations && settings.optimizations);
        wasmRunner.run(projectBuilder.runnableFile(), [])
    }

    function attemptDebug() {
        if (dbugger.running)
            return;

        if (editor.invalidated)
            return;

        if (!projectBuilder.isRunnable()) {
            hud.hudLabel.flashMessage(qsTr("Not a runnable project..."));
            return;
        }

        const killOnly = wasmRunner.running;

        wasmRunner.kill();
        if (killOnly)
            return;

        consoleView.show();
        showDebugArea = true;
        wasmRunner.configure(settings.stackSize,
                             settings.heapSize,
                             settings.threads,
                             platformProperties.supportsOptimizations);
        dbugger.debug(projectBuilder.runnableFile(), [])
    }

    function attemptScriptRun() {
        const killOnly = pyRunner.running

        pyRunner.kill();
        if (killOnly)
            return;

        consoleView.show()
        pyRunner.run(editor.file.path, [])
    }

    function attemptReplRun() {
        const killOnly = pyRunner.running

        pyRunner.kill();
        if (killOnly)
            return;

        consoleView.show()
        pyRunner.runRepl()
    }

    function stopRunAndDebug() {
        stopRequested = true
        debugRequested = false
        runRequested = false
        releaseRequested = false

        if (dbugger.running)
            dbugger.killDebugger()
        if (wasmRunner.running)
            wasmRunner.kill()
        if (pyRunner.running)
            pyRunner.kill()
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

    signal reloadFilestructure()

    onActiveChanged: {
        if (active) {
            cleanObsoleteProjects()
            projectList.refresh()
        } else {
            saveCurrentFile()
        }
        root.reloadFilestructure()
    }

    onWidthChanged: {
        // Hide the sidebar
        if (width < height && shouldAllowSidebar) {
            showLeftSideBar = false
        } else {
            showLeftSideBar = true
        }

        reevaluateDebuggerVisibility();
    }

    function reevaluateDebuggerVisibility() {
        // Hide the debug area on small screens
        if (width >= height && shouldAllowDebugArea) {
            showDebugArea = true;
        } else if (width < height) {
            showDebugArea = false;
        } else {
            showDebugArea = shouldAllowDebugArea;
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+S"
        enabled: !editor.invalidated
        onActivated: editor.autocomplete()
    }
    Shortcut {
        sequence: "Ctrl+Space"
        enabled: !editor.invalidated
        onActivated: editor.autocomplete()
    }

    Shortcut {
        sequence: "Ctrl+B"
        enabled: !editor.invalidated
        onActivated: {
            editor.saveRequested()
            editor.buildRequested()
        }
    }

    Shortcut {
        sequence: "Ctrl+R"
        enabled: !editor.invalidated
        onActivated: {
            editor.saveRequested()
            editor.runRequested()
        }
    }

    Shortcut {
        sequence: "Ctrl+S"
        enabled: !editor.invalidated
        onActivated: editor.saveRequested()
    }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: !editor.invalidated
        onActivated: editor.findRequested()
    }

    Shortcut {
        sequence: "Ctrl+Shift+F"
        enabled: !editor.invalidated
        onActivated: {
            editor.format()
        }
    }

    Item {
        id: floatingOverlayHeaderArea
        height: headerBarHeight
        parent: paddedOverlayArea
        z: paddedOverlayArea.flashThroughZ
        anchors {
            left: parent.left
            leftMargin: paddingLarge
            right: parent.right
            rightMargin: paddingLarge
        }
        visible: dialogShadow.opacity > 0.0
    }

    Item {
        id: mainViewHeader
        y: uiIntegration.insetTop
        height: headerBarHeight
        anchors {
            left: mainContainer.left
            leftMargin: paddingLarge
            right: mainContainer.right
            rightMargin: paddingLarge
        }

        RowLayout {
            id: headerRow
            parent: dialogShadow.visible ? floatingOverlayHeaderArea : mainViewHeader
            spacing: paddingLarge
            width: parent.width
            height: parent.height

            TideHeaderButton {
                id: contextButton
                enabled: !sysrootManager.installing
                source: Qt.resolvedUrl("qrc:/assets/ellipsis.circle@2x.png")
                color: root.headerItemColor
                height: headerItemHeight

                function wiggle() {
                    if (!settings.wiggleHints)
                        return
                    contextButtonWiggleAnimation.restart()
                }

                ParallelAnimation {
                    id: contextButtonWiggleAnimation
                    SequentialAnimation {
                        NumberAnimation {
                            target: contextButton
                            property: "rotation"
                            duration: 50
                            from: 0
                            to: -45
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: contextButton
                            property: "rotation"
                            duration: 100
                            from: -45
                            to: 45
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: contextButton
                            property: "rotation"
                            duration: 50
                            from: 45
                            to: 0
                            easing.type: Easing.Linear
                        }
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: contextButton
                            property: "x"
                            duration: 50
                            from: 0
                            to: -10
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: contextButton
                            property: "x"
                            duration: 100
                            from: -10
                            to: 10
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: contextButton
                            property: "x"
                            duration: 50
                            from: 10
                            to: 0
                            easing.type: Easing.Linear
                        }
                    }
                }

                TideMenu {
                    id: contextMenu
                    parent: paddedOverlayArea
                    z: paddedOverlayArea.contextMenuZ

                    MenuItem {
                        id: settingsButton
                        icon.source: Qt.resolvedUrl("qrc:/assets/gearshape.fill@2x.png")
                        text: qsTr("Settings")

                        onClicked: {
                            root.toggleSettingsDialog()
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

            TideHeaderButton {
                id: sideBarButton
                source: Qt.resolvedUrl("qrc:/assets/sidebar.left@2x.png")
                color: root.headerItemColor
                visible: shouldAllowSidebar
                height: headerItemHeight
                onClicked: showLeftSideBar = !showLeftSideBar
            }

            Item {
                Layout.fillWidth: root.landscapeMode
            }

            Row {
                id: hud
                property alias hudLabel : hudLabel
                property alias prefixLabel : prefixLabel
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                width: Math.min(implicitWidth, parent.width - (8 * headerItemHeight)) // 6 header items + 2 for padding
                height: implicitHeight
                spacing: paddingSmall
                visible: landscapeMode

                BusyIndicator {
                    id: hudIndicator
                    visible: platformProperties.usesHudBusyIndicator && (wasmRunner.running || projectBuilder.building || dbugger.running || git.busy)
                    running: visible
                }

                Label {
                    id: prefixLabel
                    color: headerItemColor
                    elide: Text.ElideRight
                    font.bold: true
                    width: implicitWidth
                    height: implicitHeight

                    readonly property string project : {
                        let target = "";

                        if (editor.file.name.endsWith(".py")) {
                            if (!editor.invalidated)
                                target = editor.file.name
                        } else {
                            const crumbs = projectBuilder.projectFile.split('/');
                            if (crumbs.length > 0) {
                                target = crumbs[crumbs.length - 1]
                            }
                        }

                        return target
                    }

                    text: {
                        if (project.length > 0) {
                            if (dbugger.running)
                                return qsTr("Debugging: %1").arg(project)
                            else if (projectBuilder.building)
                                return qsTr("Building: %1").arg(project)
                            else
                                return qsTr("Active: %1").arg(project)
                        }
                        return ""
                    }
                }

                Label {
                    color: headerItemColor
                    font.bold: true
                    width: implicitWidth
                    height: implicitHeight
                    text: "|"
                    property bool visibility: hudLabel.text !== "" && prefixLabel.text !== ""
                    visible: opacity > 0.0
                    opacity: visibility ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }

                Label {
                    id: hudLabel
                    color: headerItemColor
                    elide: Text.ElideRight
                    font.bold: true
                    width: text !== "" ? implicitWidth : 0
                    height: font.pixelSize
                    property string flashyMessage : ""
                    property string stickyMessage : {
                        if (pyRunner.running && pyRunner.isRepl) {
                            return qsTr("Python REPL running")
                        }

                        if (runners.atLeastOneRunning && consoleView.consoleOutput.count > 0) {
                            let lastLine = consoleView.consoleOutput.get(consoleView.consoleOutput.count - 1).content
                            if (lastLine.includes("\n")) {
                                const lastLineSplit = lastLine.split('\n')
                                if (lastLineSplit[lastLineSplit.length - 1] === "" &&
                                        lastLineSplit.length - 2 >= 0)
                                    lastLine = lastLineSplit[lastLineSplit.length - 2]
                                else
                                    lastLine = lastLineSplit[lastLineSplit.length - 1]
                            }
                            return qsTr("Console: ") + lastLine
                        }

                        return qsTr("Tide IDE")
                    }
                    text: {
                        return (flashyMessage !== "") ? flashyMessage : stickyMessage
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutExpo
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutExpo
                        }
                    }

                    function flashMessage(msg) {
                        flashMessageWithDuration(msg, 3000)
                    }

                    function flashMessageWithDuration(msg, duration) {
                        hudLabel.flashyMessage = msg
                        hudLabel.width = hudLabel.implicitWidth
                        hudLabelHideTimer.stop()
                        hudLabelHideTimer.interval = duration
                        hudLabelHideTimer.start()
                    }

                    Timer {
                        id: hudLabelHideTimer
                        repeat: false
                        onTriggered: {
                            hudLabel.flashyMessage = ""
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            /*TideToolButton {
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

            TideHeaderButton {
                visible: true
                enabled: !runtimeRunner.running
                source: Qt.resolvedUrl("qrc:/assets/hammer.fill@2x.png")
                color: root.palette.button
                height: headerItemHeight

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
            }*/

            TideHeaderButton {
                id: contextFieldSearchButton
                source: Qt.resolvedUrl("qrc:/assets/magnifyingglass.circle.fill@2x.png")
                color: root.headerItemColor
                height: headerItemHeight
                visible: !editor.invalidated
                onVisibleChanged: contextFieldSearchButton.wiggle()

                function wiggle() {
                    if (!settings.wiggleHints)
                        return
                    contextFieldButtonWiggleAnimation.restart()
                }

                SequentialAnimation {
                    id: contextFieldButtonWiggleAnimation
                    NumberAnimation {
                        target: contextButton
                        property: "rotation"
                        duration: 50
                        from: 0
                        to: -45
                        easing.type: Easing.Linear
                    }
                    NumberAnimation {
                        target: contextButton
                        property: "rotation"
                        duration: 100
                        from: -45
                        to: 45
                        easing.type: Easing.Linear
                    }
                    NumberAnimation {
                        target: contextButton
                        property: "rotation"
                        duration: 50
                        from: 45
                        to: 0
                        easing.type: Easing.Linear
                    }
                }

                onClicked: {
                    let root = editor.file.path
                    if (contextDialog.visibility)
                        contextDialog.hide()
                    else
                        contextDialog.show(root)
                }
            }

            TideHeaderButton {
                id: debugHeaderButton
                //rightPadding: paddingMedium
                source: Qt.resolvedUrl("qrc:/assets/ladybug.fill@2x.png")
                color: root.headerItemColor
                visible: projectBuilder.projectFile !== "" && projectBuilder.isRunnable()
                height: headerItemHeight

                onClicked: debugContextMenu.open()
                onPressAndHold: debugContextMenu.open()

                function wiggle() {
                    if (!settings.wiggleHints)
                        return
                    debugHeaderButtonWiggleAnimation.restart()
                }

                ParallelAnimation {
                    id: debugHeaderButtonWiggleAnimation
                    SequentialAnimation {
                        NumberAnimation {
                            target: debugHeaderButton
                            property: "rotation"
                            duration: 50
                            from: 0
                            to: -45
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: debugHeaderButton
                            property: "rotation"
                            duration: 100
                            from: -45
                            to: 45
                            easing.type: Easing.Linear
                        }
                        NumberAnimation {
                            target: debugHeaderButton
                            property: "rotation"
                            duration: 50
                            from: 45
                            to: 0
                            easing.type: Easing.Linear
                        }
                    }
                }

                TideMenu {
                    id: debugContextMenu
                    z: debuggerArea.z + 1 // Otherwise the debuggerArea overlaps the contextMenu
                    MenuItem {
                        text: !showDebugArea ?
                                  qsTr("Show debugger") :
                                  qsTr("Hide debugger")
                        icon.source: Qt.resolvedUrl("qrc:/assets/sidebar.squares.right@2x.png")
                        onTriggered: {
                            showDebugArea = !showDebugArea
                        }
                    }
                    MenuItem {
                        text: qsTr("Add breakpoint")
                        icon.source: Qt.resolvedUrl("qrc:/assets/plus.circle.fill@2x.png")
                        onTriggered: {
                            root.showDialog(breakpointDialogComponent)
                        }

                        Component {
                            id: breakpointDialogComponent
                            TideDialog {
                                id: breakpointDialog
                                title: qsTr("Add a breakpoint")
                                standardButtons: Dialog.Ok | Dialog.Cancel
                                anchors.centerIn: parent
                                width: mainView.dialogWidth
                                height: mainView.dialogHeight
                                Component.onCompleted: {
                                    imFixer.setupImEventFilter(breakpointSymbol)
                                    breakpointAutocompletor.reload()
                                }

                                signal done()

                                Column {
                                    id: breakpointDialogColumn
                                    width: parent.width
                                    height: parent.height
                                    spacing: paddingSmall

                                    TextField {
                                        id: breakpointSymbol
                                        width: parent.width
                                        height: implicitHeight
                                        placeholderText: qsTr("Symbol or filename:linenumber")
                                        focus: true
                                        validator: RegularExpressionValidator {
                                            regularExpression: /^([a-zA-Z0-9_.-]|[a-zA-Z0-9_.-].[cxx|cpp|c|h]:[0-9])*$/
                                        }
                                        onAccepted: breakpointDialog.accept()

                                        Keys.onUpPressed:
                                            (event) => {
                                                breakpointAutocompletor.list.currentIndex = Math.max(breakpointAutocompletor.list.currentIndex - 1, 0)
                                                event.accepted = true
                                            }
                                        Keys.onDownPressed:
                                            (event) => {
                                                breakpointAutocompletor.list.currentIndex =
                                                Math.min(breakpointAutocompletor.list.currentIndex + 1, breakpointAutocompletor.list.model.length - 1)
                                                event.accepted = true
                                            }
                                    }

                                    AutocompletorFrame {
                                        id: breakpointAutocompletor
                                        width: breakpointSymbol.width
                                        height: breakpointDialog.height - breakpointSymbol.height - breakpointDialogColumn.spacing
                                        input: breakpointSymbol
                                        projectBuilder: root.projectBuilder
                                        fileHint: editor.file
                                    }
                                }

                                onAccepted: {
                                    let type = "break"
                                    let canonicalName = breakpointSymbol.text
                                    if (breakpointAutocompletor.list.model.length > 0) {
                                        let suggestion = breakpointAutocompletor.list.model[breakpointAutocompletor.list.currentIndex]
                                        if (suggestion.kind !== AutoCompleter.Function) {
                                            type = "watch"
                                        }

                                        canonicalName = suggestion.name
                                        if (suggestion.detail !== "") {
                                            canonicalName = suggestion.detail + "::" + suggestion.name
                                        }
                                    }

                                    if (canonicalName !== "") {
                                        if (type === "break")
                                            dbugger.addBreakpoint(canonicalName)
                                        /*else if (type === "watch") {
                                            dbugger.addWatchpoint(inputText)
                                        }*/
                                    }
                                    done()
                                }

                                onRejected: {
                                    done()
                                }
                            }
                        }

                    }
                    MenuItem {
                        enabled: dbugger.running
                        text: dbugger.paused ? qsTr("Continue") : qsTr("Interrupt")
                        icon.source: dbugger.paused ? Qt.resolvedUrl("qrc:/assets/play.circle@2x.png") :
                                                      Qt.resolvedUrl("qrc:/assets/pause.circle@2x.png")
                        icon.color: dbugger.paused && !dbugger.heatingUp ?
                                        "darkorange" : enabled ?
                                            root.palette.windowText :
                                            root.palette.midlight
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

            TideHeaderButton {
                id: mainPlayButton
                //rightPadding: paddingMedium

                readonly property bool idle: !projectBuilder.building && !wasmRunner.running && !pyRunner.running && !dbugger.running

                source: idle ?
                            Qt.resolvedUrl("qrc:/assets/play.fill@2x.png") :
                            Qt.resolvedUrl("qrc:/assets/stop.fill@2x.png")
                color: root.headerItemColor
                visible: projectBuilder.projectFile !== "" || (!editor.invalidated && editor.file.name.endsWith(".py")) || pyRunner.running
                height: headerItemHeight

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
                    z: debuggerArea.z + 1 // Otherwise the debuggerArea overlaps the contextMenu
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
                        id: runMenuItem
                        readonly property bool isRunning: wasmRunner.running || pyRunner.running
                        readonly property bool isRunnableScript: (!editor.invalidated && editor.file.name.endsWith(".py"))
                        text: !isRunning ? qsTr("Run %1").arg(prefixLabel.project) : qsTr("Stop")
                        icon.source: !isRunning ?
                                         Qt.resolvedUrl("qrc:/assets/play.fill@2x.png") :
                                         Qt.resolvedUrl("qrc:/assets/stop.fill@2x.png")
                        enabled: !projectBuilder.building &&
                                 ((projectBuilder.projectFile !== ""  && projectBuilder.runnable) || isRunnableScript) ||
                                 pyRunner.running
                        onTriggered: {
                            if (!isRunning) {
                                if (isRunnableScript) {
                                    root.attemptScriptRun()
                                } else {
                                    root.debugRequested = false
                                    root.runRequested = true
                                    root.attemptBuild()
                                }
                            } else {
                                root.stopRunAndDebug()
                            }
                        }
                    }
                    MenuItem {
                        property bool visibility: openFiles.files.length > 0 && projectBuilder.projectFile !== "" && projectBuilder.runnable
                        enabled: !projectBuilder.building && !dbugger.running && visibility
                        text: qsTr("Debug")
                        icon.source: Qt.resolvedUrl("qrc:/assets/ladybug.fill@2x.png")
                        onClicked: {
                            root.debugRequested = true
                            root.runRequested = false
                            root.attemptBuild()
                        }
                    }

                    MenuItem {
                        readonly property bool visibility : projectBuilder.projectFile !== ""
                        id: releaseButton
                        enabled: !projectBuilder.building && !dbugger.running && visibility
                        text: qsTr("Release")
                        icon.source: Qt.resolvedUrl("qrc:/assets/suitcase.fill@2x.png")
                        onClicked: {
                            releaseRequested = true
                            root.attemptBuild()
                        }
                    }
                }
            }

            TideHeaderButton {
                source: Qt.resolvedUrl("qrc:/assets/terminal.fill@2x.png")
                color: root.headerItemColor
                //rightPadding: paddingMedium
                enabled: !sysrootManager.installing
                height: headerItemHeight
                onClicked: {
                    consoleContextMenu.open()
                }
                onPressAndHold: {
                    consoleContextMenu.open()
                }

                TideMenu {
                    id: consoleContextMenu
                    z: debuggerArea.z + 1 // Otherwise the debuggerArea overlaps the contextMenu
                    MenuItem {
                        text: consoleView.visibility ? qsTr("Hide console") : qsTr("Show console")
                        icon.source: Qt.resolvedUrl("qrc:/assets/terminal.fill@2x.png")
                        onPressed: {
                            if (consoleView.visibility)
                                consoleView.hide()
                            else
                                consoleView.show()
                            consoleContextMenu.close()
                        }
                    }
                    MenuItem {
                        text: qsTr("Run Python REPL")
                        icon.source: Qt.resolvedUrl("qrc:/assets/repeat.circle.fill@2x.png")
                        enabled: !runners.atLeastOneRunning && !projectBuilder.building
                        onPressed: {
                            root.attemptReplRun()
                            consoleContextMenu.close()
                        }
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

    property var projectBuilder : ProjectBuilder {
        id: projectBuilder

        function isLoadable(file) {
            if (file.name.endsWith(".pro"))
                return true;

            if (platformProperties.supportsCMake && file.name === "CMakeLists.txt")
                return true;

            if (platformProperties.supportsSnaps && file.name === "snapcraft.yaml")
                return true;

            if (platformProperties.supportsClickable && (file.name === "clickable.json" || file.name === "clickable.yaml"))
                return true;

            return false;
        }

        onProjectFileChanged: {
            reevaluateDebuggerVisibility()

            if (projectFile === "")
                return

            hud.hudLabel.flashMessageWithDuration(qsTr("Switched project"), 3000)
        }

        onCleaned: {
            hud.hudLabel.flashMessage(qsTr("Clean finished"))
        }

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
                hud.hudLabel.flashMessage(qsTr("Build finished"))
                warningSign.flashWarning(qsTr("Build failed"))
            }
        onBuildSuccess:
            (debug) => {
                compiling = false
                hud.hudLabel.flashMessage(qsTr("Build finished"))
                warningSign.flashSuccess(qsTr("Build successful"))

                if (debug) {
                    root.attemptDebug()
                    debugRequested = false
                } else if (runRequested) {
                    root.attemptRun()
                    runRequested = false
                }

                if (releaseRequested) {
                    releaseRequested = false
                    const coords = mainPlayButton.mapToGlobal(0, 0)
                    const pos = Qt.rect(coords.x, coords.y, mainPlayButton.width, mainPlayButton.height)
                    iosSystem.share("", "file://" + projectBuilder.runnableFile(), pos)
                }
            }
    }

    GitClient {
        id: git

        onRepoCloned:
            (url, name) => {
                console.log("Repo cloned")
                hud.hudLabel.flashMessage(qsTr("Repo '%1' cloned").arg(name))
                mainBackgroundColorOverride = "teal"
                root.reloadFilestructure()
            }
        onRepoCloneStarted:
            (url, name) => {
                hud.hudLabel.flashMessage(qsTr("Started cloning '%1'").arg(name))
            }

        onRepoExists:
            (path, name) => {
                console.log("Repo already exists")
                hud.hudLabel.flashMessage(qsTr("'%1' already exists").arg(name))
                mainBackgroundColorOverride = "red"
            }
    }

    PlatformProperties {
        id: platformProperties
    }

    QtObject {
        id: runners

        readonly property bool atLeastOneRunning : pyRunner.running || wasmRunner.running

        property var pyRunner : PyRunner {
            id: pyRunner
            system: iosSystem
            onRunningChanged: {
                if (running) {
                    hud.hudLabel.flashMessageWithDuration(qsTr("Started"), 1000)
                } else {
                    hud.hudLabel.flashMessage(qsTr("Stopped"))
                }

                if (running && settings.clearConsole)
                    clearConsoleOutput()

                if (!running) {
                    if (!root.stopRequested) {
                        warningSign.flashSuccess(qsTr("Execution ended"))
                    }
                    root.stopRequested = false
                }
            }

            onRunEnded:
                (exitCode) => {
                    if (exitCode === 255) {
                        hud.hudLabel.flashMessage(qsTr("Terminated!"))
                        warningSign.flashStop(qsTr("Execution stopped"))
                    }
                }

            onErrorOccured:
                (str) => {
                    consoleView.consoleOutput.append({"content": str, "stdout": false})
                    consoleView.show()
                    consoleView.consoleScrollView.positionViewAtEnd()
                    if (!root.stopRequested) {
                        warningSign.flashWarning(qsTr("Error occured"))
                    }
                }
        }

        property var wasmRunner : WasmRunner {
            id: wasmRunner
            system: iosSystem
            forceDebugInterpreter: settings.fallbackInterpreter
            onRunningChanged: {
                if (running) {
                    hud.hudLabel.flashMessageWithDuration(qsTr("Started"), 1000)
                } else {
                    hud.hudLabel.flashMessage(qsTr("Stopped"))
                }

                if (running && settings.clearConsole)
                    clearConsoleOutput()

                if (!running) {
                    if (!root.stopRequested) {
                        warningSign.flashSuccess(qsTr("Execution ended"))
                    }
                    root.stopRequested = false
                }
            }
            onMessage:
                (msg) => {
                    hud.hudLabel.flashMessage(msg);
                }

            onRunEnded:
                (exitCode) => {
                    if (exitCode === 255) {
                        hud.hudLabel.flashMessage(qsTr("Terminated!"))
                        warningSign.flashStop(qsTr("Execution stopped"))
                    }
                }

            onErrorOccured:
                (str) => {
                    consoleView.consoleOutput.append({"content": str, "stdout": false})
                    consoleView.show()
                    consoleView.consoleScrollView.positionViewAtEnd()
                    if (!root.stopRequested) {
                        warningSign.flashWarning(qsTr("Error occured"))
                    }
                }
        }
    }

    Debugger {
        id: dbugger
        runner: wasmRunner
        system: iosSystem

        readonly property bool heatingUp : delayedDebugContinue.running
        readonly property bool initialized : {
            dbugger.waitingpoints.length;
            reevaluateDebuggerVisibility()
            return true
        }

        onRunningChanged: {
            if (running)
                hud.hudLabel.flashMessage(qsTr("Debugging started"))
            else
                hud.hudLabel.flashMessage(qsTr("Debugging stopped"))

            showDebugArea = shouldAllowDebugArea;
            if (running) {
                dbugger.clearBacktrace();
                dbugger.clearFrameValues();
            }
            if (running && settings.clearConsole)
                clearConsoleOutput()
        }
        onHintPauseMessage: {
            warningSign.flashPause(qsTr("Breakpoint reached"))
            debugHeaderButton.wiggle()
        }

        onProcessPaused: {
            dbugger.getBacktraceAndFrameValues();
            if (!heatingUp) {
                hud.hudLabel.flashMessageWithDuration(qsTr("Debugging paused"), Number.MAX_VALUE)
            }
        }
        onProcessContinued: {
            hud.hudLabel.flashMessage(qsTr("Program continued"))
        }

        readonly property bool hasCurrentLineOfExecution : dbugger.currentLineOfExecution.startsWith(editor.file.path + ":")

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
            pyRunner.prepareStdio(spec)
        });
        iosSystem.setupStdIo()

        sysrootManager.installBundledSysroot();

        projectBuilder.commandRunner = iosSystem
        projectBuilder.setSysroot(sysroot);
        editor.autoCompleter.setSysroot(sysroot);
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

    function fileIsImageFile(path) {
        return path.toLowerCase().endsWith(".png") ||
                path.toLowerCase().endsWith(".jpg") ||
                path.toLowerCase().endsWith(".jpeg") ||
                path.toLowerCase().endsWith(".gif") ||
                path.toLowerCase().endsWith(".svg")
    }

    function openEditor(modelData) {
        if (!fileIo.fileIsTextFile(modelData.path)) {
            if (!fileIsImageFile(modelData.path)) {
                hud.hudLabel.flashMessage("Not opening binary file...");
                return;
            }
        }

        saveCurrentFile()

        openFiles.push(modelData);
        editor.file = modelData;

        // Also load project in case it's a project
        if (modelData.path.endsWith(".pro") || projectBuilder.isLoadable(modelData))
            projectBuilder.loadProject(modelData.path);

        if (root.width < root.height)
            showLeftSideBar = false;
    }

    function openEditorFile(file) {
        const listing = openFiles.open(file);
        openEditor(listing)
    }

    PlatformIntegrationDelegate {
        id: uiIntegration
        property int insetTop : platformProperties.supportsEmbeddedStatusbar ? uiIntegration.statusBarHeight : 0
        property int topPadding : platformProperties.supportsEmbeddedStatusbar ? 0 : paddingMedium
    }

    readonly property int uiIntegrationOskPadding : uiIntegration.oskVisible ? uiIntegration.oskHeight : 0
    readonly property int vkOskPadding : inputPanel.inUse && Qt.inputMethod.visible ? inputPanel.height : 0
    readonly property int qtOskPadding : Qt.inputMethod.visible ? Qt.inputMethod.keyboardRectangle.height / (gridUnitPx / 8): 0
    readonly property int actualOskPadding: {
        if (platformProperties.usesUiDelegateForOskHeight)
            return uiIntegrationOskPadding
        else if (platformProperties.usesQtForOskHeight)
            return qtOskPadding
        else
            return vkOskPadding
    }
    onActualOskPaddingChanged: console.log("OSK padding: " + actualOskPadding)

    // Main container
    Item {
        id: mainContainer
        anchors.top: mainViewHeader.bottom
        width: parent.width
        height: parent.height - headerBarHeight - actualOskPadding
        focus: true

        /*Behavior on height {
            NumberAnimation {
                easing.type: Easing.OutCubic
                duration: 300
            }
        }*/

        Component.onCompleted: {
            uiIntegration.item = mainContainer
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

            Label {
                Layout.preferredWidth: parent.width
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                font.pixelSize: startPage.sideLength
                color: root.palette.text
                text: qsTr("Tide IDE")
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                width: parent.width
                height: root.toolBarHeight
                spacing: paddingMedium
                Layout.alignment: Qt.AlignHCenter

                TideButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/plus.circle@2x.png")
                    font.pixelSize: startPage.sideLength
                    height: parent.height
                    color: root.palette.button
                    text: qsTr("Create")
                    onClicked: {
                        root.showDialog(createProjectDialogComponent)
                    }
                }
                TideButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/icloud.and.arrow.down@2x.png")
                    font.pixelSize: startPage.sideLength
                    height: parent.height
                    color: root.palette.button
                    text: qsTr("Clone")
                    onClicked: root.showDialog(cloneDialogComponent)
                }
            }

            Row {
                width: parent.width
                spacing: paddingMedium
                Layout.alignment: Qt.AlignHCenter

                TideButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/square.and.arrow.down.on.square@2x.png")
                    font.pixelSize: startPage.sideLength
                    height: parent.height
                    color: root.palette.button
                    text: qsTr("Import")
                    onClicked: projectPicker.startImport()
                }

                TideButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/link@2x.png")
                    font.pixelSize: startPage.sideLength
                    height: startPage.sideLength
                    color: root.palette.button
                    text: qsTr("Examples")
                    onClicked: {
                        git.clone("https://github.com/fredldotme/TideExamples", "TideExamples");
                    }
                }
            }

            Row {
                width: parent.width
                spacing: paddingMedium
                Layout.alignment: Qt.AlignHCenter

                TideButton {
                    icon.source: Qt.resolvedUrl("qrc:/assets/questionmark.circle.fill@2x.png")
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
            opacity: projectList.projects.length > 0 ? 1.0 : 0.0
            onVisibleChanged: mainView.forceLayout()

            x: !centered ? 0 : ((parent.width - width) / 2)
            y: !centered ? uiIntegration.topPadding : ((parent.height - height) / 2)
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
            Behavior on opacity {
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
                                                           (parent.width / 3) * 2
            readonly property int settingsDialogHeight: width === sideBarWidth ?
                                                            parent.height :
                                                            (parent.height / 3) * 2

            Item {
                id: leftSideBar
                width: showLeftSideBar ?
                           (sideBarWidth - (root.landscapeMode ? 0 : paddingMedium)) :
                           0
                height: parent.height

                Behavior on width {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic; }
                }

                Item {
                    id: projectsArea
                    x: paddingMedium
                    width: parent.width - paddingMedium
                    height: parent.height - (paddingMedium * 2)
                    readonly property int spaceBetweenSections : openFiles.files.length > 0 ? paddingTiny : 0

                    property var project : null
                    onProjectChanged: {
                        git.path = getRepoPathFromProject(project)
                    }

                    function getRepoPathFromProject(project) {
                        if (project.isBookmark) {
                            const bookmarkPath = projectPicker.openBookmark(project.bookmark)
                            return bookmarkPath
                        } else {
                            return project.path
                        }
                    }

                    Column {
                        width: parent.width
                        height: parent.height
                        spacing: projectsArea.spaceBetweenSections

                        Item {
                            id: projectNavigationContainer
                            y: paddingSmall
                            width: parent.width
                            height: parent.height - openFilesArea.height - paddingMedium

                            Rectangle {
                                id: projectNavigationRectangle
                                anchors.fill: parent

                                color: root.palette.base
                                radius: roundedCornersRadiusMedium
                                border.color: root.borderColor
                                border.width: 1

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
                                            border.color: root.borderColor
                                            border.width: 1
                                            color: root.palette.base
                                            clip: true

                                            property var project : null
                                            onProjectChanged: {
                                                projectsArea.project = project
                                            }

                                            ListView {
                                                id: projectListView
                                                headerPositioning: ListView.PullBackHeader
                                                header: Item {
                                                    width: projectNavigationStack.width
                                                    height: root.toolBarHeight
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        spacing: paddingSmall * 2
                                                        ToolButton {
                                                            Layout.leftMargin: paddingSmall
                                                            text: qsTr("Create")
                                                            icon.source: Qt.resolvedUrl("qrc:/assets/plus.circle@2x.png")
                                                            icon.color: root.palette.button
                                                            icon.width: headerItemHeight
                                                            icon.height: headerItemHeight
                                                            onClicked: {
                                                                root.showDialog(createProjectDialogComponent)
                                                            }
                                                        }
                                                        ToolButton {
                                                            text: qsTr("Clone")
                                                            icon.source: Qt.resolvedUrl("qrc:/assets/icloud.and.arrow.down@2x.png")
                                                            icon.color: root.palette.button
                                                            icon.width: headerItemHeight
                                                            icon.height: headerItemHeight
                                                            onClicked: {
                                                                root.showDialog(cloneDialogComponent)
                                                            }
                                                        }
                                                        ToolButton {
                                                            Layout.rightMargin: paddingSmall
                                                            text: qsTr("Import")
                                                            icon.source: Qt.resolvedUrl("qrc:/assets/square.and.arrow.down.on.square@2x.png")
                                                            icon.color: root.palette.button
                                                            icon.width: headerItemHeight
                                                            icon.height: headerItemHeight
                                                            onClicked: projectPicker.startImport()
                                                        }
                                                    }
                                                }

                                                ScrollBar.vertical: TideScrollBar {
                                                    parent: projectListView
                                                }

                                                Connections {
                                                    target: projectCreator
                                                    function onProjectCreated() {
                                                        projectList.refresh()
                                                    }
                                                }

                                                Connections {
                                                    target: root
                                                    function onReloadFilestructure() {
                                                        projectList.refresh()
                                                    }
                                                }

                                                property bool refreshFlick : false
                                                onFlickStarted: {
                                                    refreshFlick = atYBeginning
                                                }
                                                onFlickEnded: {
                                                    if (atYBeginning && refreshFlick)
                                                    {
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
                                                    width: parent.width
                                                    height: font.pixelSize + (paddingMid * 2)
                                                    iconWidth: 16
                                                    iconHeight: 16
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
                                                        git.path = projectsArea.getRepoPathFromProject(modelData)
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
                                                                Qt.openUrlExternally(dirOpenProtocol + projectsContextMenu.selectedProject.path)
                                                            }
                                                        }

                                                        MenuItem {
                                                            text: qsTr("Remove")
                                                            icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")

                                                            function causeDeletion() {
                                                                if (projectsContextMenu.selectedProject.isBookmark) {
                                                                    const bookmark = projectsContextMenu.selectedProject.bookmark
                                                                    openFiles.closeAllByBookmark(bookmark)
                                                                    bookmarkDb.removeBookmark(bookmark)
                                                                } else {
                                                                    projectList.removeProject(projectsContextMenu.selectedProject.path)
                                                                }
                                                                projectsContextMenu.selectedProject = null
                                                            }

                                                            onClicked: {
                                                                let deletionDialog = null;
                                                                if (projectsContextMenu.selectedProject.isBookmark)
                                                                    deletionDialog = root.showDialog(bookmarkRemoveDialogComponent)
                                                                else
                                                                    deletionDialog = root.showDialog(sureDialogComponent)
                                                                deletionDialog.accepted.connect(causeDeletion)
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
                                            border.color: root.borderColor
                                            border.width: 1
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

                                                ScrollBar.vertical: TideScrollBar {
                                                    parent: directoryListView
                                                }

                                                property var project : null
                                                onProjectChanged: {
                                                    projectsArea.project = project
                                                }

                                                function refresh() {
                                                    projectsArea.project = project
                                                    if (project.isBookmark) {
                                                        model = projectPicker.listBookmarkContents(project.bookmark)
                                                        if (model.length === 0) {
                                                            model = projectList.listDirectoryContents(project.path)
                                                        }
                                                    } else {
                                                        model = projectList.listDirectoryContents(project.path)
                                                    }
                                                }

                                                function getDetailText(listing) {
                                                    if (listing.type === DirectoryListing.Directory) {
                                                        return qsTr("%1 contents").arg(fileIo.directoryContents(listing.path))
                                                    } else {
                                                        return qsTr("%1 bytes").arg(fileIo.fileSize(listing.path))
                                                    }
                                                }

                                                property bool refreshFlick : false
                                                onFlickStarted: {
                                                    refreshFlick = atYBeginning
                                                }
                                                onFlickEnded: {
                                                    if (atYBeginning && refreshFlick)
                                                    {
                                                        refresh()
                                                    }
                                                }

                                                Component.onCompleted: {
                                                    refresh()
                                                    projectsArea.project = project
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
                                                Connections {
                                                    target: root
                                                    function onReloadFilestructure() {
                                                        directoryListView.refresh()
                                                    }
                                                }

                                                headerPositioning: ListView.PullBackHeader
                                                header: Rectangle {
                                                    width: projectNavigationStack.width
                                                    height: root.toolBarHeight
                                                    clip: true
                                                    color: "transparent"
                                                    radius: roundedCornersRadiusMedium
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        spacing: paddingSmall * 2
                                                        TideToolButton {
                                                            icon.source: Qt.resolvedUrl("qrc:/assets/doc.badge.plus@2x.png")
                                                            icon.color: root.palette.button
                                                            leftPadding: paddingMedium
                                                            Layout.alignment: Qt.AlignLeft
                                                            Layout.leftMargin: paddingSmall
                                                            onClicked: {
                                                                let newFileDialog = root.showDialog(newFileDialogComponent)
                                                                newFileDialog.rootPath = directoryListView.project.path
                                                                newFileDialog.open();
                                                            }
                                                        }
                                                        TideToolButton {
                                                            icon.source: Qt.resolvedUrl("qrc:/assets/plus.rectangle.on.folder@2x.png")
                                                            icon.color: root.palette.button
                                                            height: parent.height
                                                            Layout.alignment: Qt.AlignLeft
                                                            onClicked: {
                                                                let newDirectoryDialog = root.showDialog(newDirectoryDialogComponent)
                                                                newDirectoryDialog.rootPath = directoryListView.project.path
                                                                newDirectoryDialog.open();
                                                            }
                                                        }

                                                        Item {
                                                            Layout.fillWidth: true
                                                        }

                                                        TideToolButton {
                                                            //rightPadding: paddingMedium
                                                            text: qsTr("Status")
                                                            icon.source: Qt.resolvedUrl("qrc:/assets/arrow.triangle.branch@2x.png")
                                                            icon.color: root.palette.button
                                                            visible: gitDialog.model.length > 0 && git.hasRepo(directoryListView.project.path)
                                                            height: parent.height
                                                            Layout.alignment: Qt.AlignRight
                                                            Layout.rightMargin: paddingMedium
                                                            onClicked: {
                                                                projectsArea.project = directoryListView.project
                                                                gitDialog.show()
                                                            }
                                                        }
                                                    }
                                                }

                                                topMargin: paddingMedium
                                                delegate: FileListingButton {
                                                    id: fileListingButton
                                                    readonly property bool isBackButton : (modelData.name === "..")
                                                    readonly property bool isDir : (modelData.type === DirectoryListing.Directory)
                                                    readonly property bool isProject : projectBuilder.isLoadable(modelData)

                                                    textColor: root.palette.button
                                                    icon.color: root.palette.button
                                                    icon.source: isBackButton ? Qt.resolvedUrl("qrc:/assets/chevron.backward@2x.png")
                                                                              : (isDir ? Qt.resolvedUrl("qrc:/assets/folder@2x.png")
                                                                                       : isProject ? Qt.resolvedUrl("qrc:/assets/hammer@2x.png")
                                                                                                   : Qt.resolvedUrl("qrc:/assets/doc@2x.png"))
                                                    iconWidth: 16
                                                    iconHeight: 16
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
                                                            if (modelData.name.endsWith(".pro") &&
                                                                    modelData.path !== projectBuilder.projectFile) {
                                                                if (dbugger.waitingpoints.length > 0) {
                                                                    let dialog = root.showDialog(switchProjectDialogComponent)
                                                                    dialog.projectFile = modelData
                                                                    return;
                                                                }
                                                            }

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

                                                    Connections {
                                                        target: root
                                                        function onReloadFilestructure() {
                                                            directoryListView.refresh()
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
                                                                Qt.openUrlExternally(dirOpenProtocol + modelData.path)
                                                            }
                                                        }

                                                        MenuItem {
                                                            text: qsTr("Delete")
                                                            icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")

                                                            function causeDeletion() {
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

                                                            onClicked: {
                                                                let deletionDialog = root.showDialog(sureDialogComponent)
                                                                deletionDialog.accepted.connect(causeDeletion)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            /*MultiEffect {
                                source: projectNavigationRectangle
                                anchors.fill: projectNavigationRectangle
                                paddingRect: Qt.rect(0, 0, projectNavigationRectangle.width, projectNavigationRectangle.height)
                                shadowEnabled: true
                                shadowBlur: 1.0
                                shadowOpacity: defaultRectangleShadow
                            }*/
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
                                        (showArea ? openFilesArea.usualHeight : root.toolBarHeight) : 0

                            Behavior on height {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }

                            Rectangle {
                                id: openFilesRectangle
                                width: parent.width
                                height: parent.height
                                radius: roundedCornersRadiusMedium
                                border.color: root.borderColor
                                border.width: 1
                                color: root.palette.base
                                clip: true

                                ListView {
                                    id: openfilesListView
                                    width: parent.width
                                    height: parent.height
                                    topMargin: paddingMedium
                                    model: openFiles.files
                                    spacing: paddingSmall

                                    ScrollBar.vertical: TideScrollBar {
                                        parent: openfilesListView
                                    }

                                    headerPositioning: ListView.PullBackHeader
                                    header: Item {
                                        id: openFilesAreaToolbar
                                        width: projectNavigationStack.width
                                        height: root.toolBarHeight

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: paddingSmall * 2
                                            height: parent.height

                                            Item {
                                                Layout.alignment: Qt.AlignLeft
                                                Layout.leftMargin: paddingMedium
                                                width: implicitWidth
                                                height: parent.height

                                                Label {
                                                    text: openFiles.files.length === 1 ?
                                                              qsTr("1 open file") :
                                                              qsTr("%1 open files").arg(openFiles.files.length)
                                                    font.pixelSize: 16
                                                    width: implicitWidth
                                                    height: root.toolBarHeight
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter

                                                    property bool visibility : !openFilesArea.showArea
                                                    opacity: visibility ? 1.0 : 0.0
                                                    visible: opacity > 0.0
                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: 100
                                                        }
                                                    }
                                                }

                                                ToolButton {
                                                    icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")
                                                    icon.width: menuItemIconSize
                                                    icon.height: menuItemIconSize
                                                    text: qsTr("Close all")
                                                    font.pixelSize: 16

                                                    property bool visibility : openFilesArea.showArea
                                                    opacity: visibility ? 1.0 : 0.0
                                                    visible: opacity > 0.0
                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: 100
                                                        }
                                                    }

                                                    onClicked: {
                                                        console.log("Closing all " + openFiles.files.length + " files")
                                                        for (let i = openFiles.files.length - 1; i >= 0; i--) {
                                                            console.log("Closing: " + i)
                                                            openFiles.close(openFiles.files[i])
                                                        }
                                                        for (let i = dbugger.waitingpoints.length - 1; i >= 0; i--) {
                                                            if (dbugger.waitingpoints[i].type === "break")
                                                                dbugger.removeBreakpoint(dbugger.waitingpoints[i].value)
                                                            else if (dbugger.waitingpoints[i].type === "watch")
                                                                dbugger.removeWatchpoint(dbugger.waitingpoints[i].value)
                                                        }
                                                        showDebugArea = false
                                                    }
                                                }
                                            }

                                            ToolButton {
                                                Layout.alignment: Qt.AlignRight
                                                Layout.rightMargin: paddingMedium
                                                Layout.topMargin: openFilesArea.showArea ? paddingSmall : 0
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
                                        readonly property bool isProject : projectBuilder.isLoadable(modelData)
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
                                        height: mainArea.height
                                        font.pixelSize: 16
                                        onClicked: {
                                            if (modelData.name.endsWith(".pro") &&
                                                    modelData.path !== projectBuilder.projectFile) {
                                                if (dbugger.waitingpoints.length > 0) {
                                                    let dialog = root.showDialog(switchProjectDialogComponent)
                                                    dialog.projectFile = modelData
                                                    return;
                                                }
                                            }

                                            openEditor(modelData)
                                        }
                                        onPressAndHold: {
                                            let openFilesContextMenu = openFilesContextMenuComponent.createObject(openFilesEntryButton)
                                            openFilesContextMenu.selectedFile = modelData
                                            openFilesContextMenu.open()
                                        }
                                    }

                                    Component {
                                        id: switchProjectDialogComponent
                                        TideDialog {
                                            title: qsTr("You're about to switch projects");
                                            modal: true
                                            anchors.centerIn: parent
                                            standardButtons: Dialog.Ok | Dialog.Cancel

                                            property var projectFile : null

                                            signal done()

                                            Label {
                                                width: parent.width
                                                text: qsTr("Switching projects will delete already set breakpoints. Would you like to continue?")
                                            }

                                            onAccepted: {
                                                for (let i = dbugger.waitingpoints.length - 1; i >= 0; i--) {
                                                    if (dbugger.waitingpoints[i].type === "break")
                                                        dbugger.removeBreakpoint(dbugger.waitingpoints[i].value)
                                                    else if (dbugger.waitingpoints[i].type === "watch")
                                                        dbugger.removeWatchpoint(dbugger.waitingpoints[i].value)
                                                }

                                                openEditor(projectFile)
                                                done()
                                            }

                                            onRejected: {
                                                done()
                                            }
                                        }
                                    }

                                    Component {
                                        id: openFilesContextMenuComponent
                                        TideMenu {
                                            id: openFilesContextMenu
                                            property DirectoryListing selectedFile: null

                                            MenuItem {
                                                text: qsTr("Close")
                                                icon.source: Qt.resolvedUrl("qrc:/assets/xmark@2x.png")
                                                onClicked: {
                                                    let file = openFilesContextMenu.selectedFile
                                                    if (file.path === projectBuilder.projectFile)
                                                        projectBuilder.unloadProject()

                                                    if (file == editor.file)
                                                        saveCurrentFile()

                                                    openFiles.close(file)
                                                    if (openFiles.files.length > 0)
                                                        editor.file = openFiles.files[0]
                                                    else
                                                        editor.invalidate()
                                                }
                                            }
                                            MenuItem {
                                                text: openFilesContextMenu.selectedFile != null ?
                                                          qsTr("Close all but '%1'").arg(openFilesContextMenu.selectedFile.name) :
                                                          ""
                                                icon.source: Qt.resolvedUrl("qrc:/assets/xmark.shield@2x.png")
                                                enabled: openFiles.files.length > 1
                                                onClicked: {
                                                    let file = openFilesContextMenu.selectedFile
                                                    console.log("Close all but: " + file.path)
                                                    saveCurrentFile()
                                                    editor.file = file
                                                    openFiles.closeAllBut(file)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            /*MultiEffect {
                                source: openFilesRectangle
                                anchors.fill: openFilesRectangle
                                paddingRect: Qt.rect(0, 0, openFilesRectangle.width, openFilesRectangle.height)
                                shadowEnabled: true
                                shadowBlur: 1.0
                                shadowOpacity: defaultRectangleShadow
                            }*/
                        }
                    }
                }
            }

            Item {
                id: editorContainer
                width: parent.width - leftSideBar.width - debuggerArea.width
                height: parent.height - (paddingMedium) - (openFiles.files.length > 0 ? 0 : paddingSmall)
                visible: projectList.projects.length > 0

                CodeEditor {
                    id: editor
                    anchors.fill: parent
                    parent: editorContainer
                    anchors {
                        rightMargin: showDebugArea ? paddingSmall : paddingMedium
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
                        if (isRunnableScript) {
                            attemptScriptRun();
                        } else if (projectBuilder.runnable) {
                            root.runRequested = true
                            attemptBuild();
                        }
                    }
                    onInvalidatedChanged: {
                        if (invalidated) {
                            projectBuilder.projectFile = ""
                            showDebugArea = false
                        }
                    }

                    readonly property bool isRunnableScript : runMenuItem.isRunnableScript
                }
            }
        }

        Rectangle {
            id: dialogShadow
            width: parent.width
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: "#AA000000"
                }
                GradientStop {
                    position: 0.25
                    color: "#BB000000"
                }
                GradientStop {
                    position: 0.75
                    color: "#CC000000"
                }
            }

            opacity: {
                // Bindings for reevaluation
                paddedOverlayArea.children.length;
                consoleView.visible;
                gitDialog.visible;
                overlayLandingPad.visible;

                console.log("Reevaluating dialog shadow opacity: " + overlayLandingPad.visible + " " + consoleView.visible)

                if (overlayLandingPad.visible)
                    return 1.0

                if (consoleView.visible)
                    return 1.0

                if (gitDialog.visible)
                    return 1.0

                for (let i = 0; i < paddedOverlayArea.children.length; i++) {
                    if (paddedOverlayArea.children[i].visible) {
                        if (paddedOverlayArea.children[i].modal !== undefined &&
                                paddedOverlayArea.children[i].modal)
                            return 1.0
                    }
                }
                return 0.0
            }

            visible: opacity > 0.0
            parent: Overlay.overlay

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

            onVisibleChanged: {
                if (!visible && !editor.invalidated)
                    editor.codeField.forceActiveFocus()
            }
            Connections {
                target: editor
                function onFileChanged() {
                    if (!editor.invalidated)
                        editor.codeField.forceActiveFocus()
                }
            }
        }

        Item {
            id: paddedOverlayArea
            width: parent.width
            y: uiIntegration.insetTop
            height: parent.height - actualOskPadding
            parent: Overlay.overlay
            z: dialogShadow.z + 1

            readonly property int searchAndReplaceZ : z + 1
            readonly property int consoleZ : z + 2
            readonly property int debuggerZ : z + 3
            readonly property int dialogZ : z + 4
            readonly property int settingsZ : z + 5
            readonly property int helpZ : z + 6
            readonly property int warningZ : z + 7
            readonly property int contextMenuZ : z + 8
            readonly property int flashThroughZ : z + 9
            readonly property int inputPanelZ : z + 10

            Row {
                id: overlayLandingPad
                x: paddedOverlayArea.x + paddingLarge
                y: paddedOverlayArea.y + headerBarHeight
                z: paddedOverlayArea.z
                width: paddedOverlayArea.width - debuggerArea.width - (paddingLarge * 2)
                height: paddedOverlayArea.height - headerBarHeight - (paddingLarge * 2)
                spacing: paddingMedium
                visible: root.landscapeMode && !dbugger.heatingUp && dbugger.running && consoleView.visible && dbugger.currentLineOfExecution !== ""
                readonly property bool modal : visible

                Behavior on height {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic; }
                }

                Item {
                    id: consoleViewLandingPad
                    width: (parent.width / 2) - (paddingMedium / 2)
                    height: parent.height
                }

                CodeEditor {
                    id: overlayEditor
                    width: (parent.width / 2) - (paddingMedium / 2)
                    height: parent.height
                    y: consoleView.y
                    codeField.readOnly: true
                    opacity: consoleView.visibility && dbugger.paused && !dbugger.heatingUp ? 1.0 : 0.0
                    file: {
                        dbugger.currentLineOfExecution;
                        return dbugger.getFileForActiveLine()
                    }
                    fileIo: fileIo
                    projectPicker: projectPicker
                    projectBuilder: projectBuilder
                    openFiles: openFiles
                    dbugger: dbugger
                    Behavior on opacity {
                        NumberAnimation {
                            duration: dialogShadow.consoleAnimation
                            easing.type: Easing.OutCubic
                        }
                    }
                    Connections {
                        target: dbugger
                        function onCurrentLineOfExecutionChanged() {
                            let line = dbugger.currentLineOfExecution.split(':')
                            if (line.length == 0)
                                return
                            overlayEditor.scrollToLine(line[line.length - 1])
                        }
                    }
                }
            }
        }

        ConsoleView {
            id: consoleView
            width: parent == consoleViewLandingPad ?
                       parent.width:
                       !landscapeMode && showDebugArea ?
                           0 : // Don't overlap debugger area and ConsoleView in portraitMode
                           mainView.dialogWidth - (debuggerArea.width / 2)
            height: parent == consoleViewLandingPad ? parent.height : mainView.dialogHeight - parent.y
            opacityOverride: 1.0
            parent: overlayLandingPad.visible ? consoleViewLandingPad : paddedOverlayArea
            z: paddedOverlayArea.consoleZ
            inputEnabled: wasmRunner.running || pyRunner.running
        }

        ContextView {
            id: contextDialog
            width: !landscapeMode && showDebugArea ?
                       0 : // Don't overlap debugger area and ContextView in portraitMode
                       mainView.dialogWidth - (debuggerArea.width / 2)
            height: mainView.dialogHeight - paddedOverlayArea.y
            projectPicker: projectPicker
            openFiles: openFiles
            fileIo: fileIo
            dbugger: dbugger
            projectBuilder: projectBuilder
            parent: paddedOverlayArea
            z: paddedOverlayArea.searchAndReplaceZ
            onOpenRequested: {
                openEditorFile(contextDialog.currentPath)
                contextDialog.hide()
            }
        }

        /* Debugger area */
        Item {
            id: debuggerArea
            width: showDebugArea ? (sideBarWidth - paddingMedium) : 0
            height: mainContainer.height - (paddingMedium * 2) // TODO: Commonalize
            anchors.top: parent.top
            anchors.topMargin: headerBarHeight + uiIntegration.topPadding
            anchors.right: parent.right
            anchors.rightMargin: paddingSmall
            parent: paddedOverlayArea

            x: parent.width - width
            y: parent.y
            z: paddedOverlayArea.debuggerZ
            visible: width > 0

            readonly property int usableHeight : debuggerArea.height

            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // Match what the mainContainer does since this is parented to the overlay
            /*Behavior on height {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }*/

            Column {
                id: mainDebuggerColumn
                anchors.fill: parent
                spacing: paddingSmall

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: paddingSmall
                    anchors.leftMargin: paddingSmall
                    height: (debuggerArea.usableHeight / 3) - paddingSmall

                    Rectangle {
                        id: breakpointsContainer
                        anchors.fill: parent
                        radius: roundedCornersRadiusMedium
                        border.color: root.borderColor
                        border.width: 1
                        color: root.palette.base
                        clip: true

                        Label {
                            anchors.fill: parent
                            anchors.margins: paddingSmall
                            text: qsTr("No breakpoints set")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            readonly property bool visibility: dbugger.waitingpoints.length === 0
                            visible: opacity > 0.0
                            opacity: visibility ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                        }

                        ListView {
                            id: waitingPointsListView
                            anchors.fill: parent
                            anchors.margins: paddingSmall
                            clip: true
                            model: dbugger.waitingpoints
                            header: Item {
                                width: projectNavigationStack.width
                                height: root.headerBarHeight

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: paddingSmall * 2
                                    ToolButton {
                                        text: qsTr("Step over")
                                        enabled: dbugger.running
                                        onClicked: dbugger.stepOver()
                                    }
                                    ToolButton {
                                        text: qsTr("Step in")
                                        enabled: dbugger.running
                                        font.pixelSize: 16
                                        onClicked: dbugger.stepIn()
                                    }
                                    ToolButton {
                                        text: qsTr("Step out")
                                        enabled: dbugger.running
                                        font.pixelSize: 16
                                        onClicked: dbugger.stepOut()
                                    }
                                }
                            }

                            ScrollBar.vertical: TideScrollBar {
                                parent: waitingPointsListView
                            }

                            delegate: TideButton {
                                icon.source: Qt.resolvedUrl("qrc:/assets/circle.fill@2x.png")
                                icon.color: modelData.type === "break" ? "red" : "purple"
                                text: getBreakpointText()
                                width: parent.width
                                height: paddingSmall +
                                        label.implicitHeight +
                                        paddingSmall
                                font.pixelSize: 18
                                color: root.palette.button
                                onClicked: breakpointContextMenu.open()

                                function getBreakpointText() {
                                    if (modelData.value.includes("/")) {
                                        const parts = modelData.value.split("/")
                                        return parts[parts.length - 1]
                                    } else {
                                        return modelData.value
                                    }
                                }

                                TideMenu {
                                    id: breakpointContextMenu
                                    z: paddedOverlayArea.contextMenuZ
                                    MenuItem {
                                        text: modelData.type === "break" ?
                                                  qsTr("Delete breakpoint") :
                                                  modelData.type === "watch" ?
                                                      qsTr("Delete watchpoint") : ""
                                        onClicked: {
                                            if (modelData.type === "break")
                                                dbugger.removeBreakpoint(modelData.value)
                                            else if (modelData.type === "watch")
                                                dbugger.removeWatchpoint(modelData.value)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    /*MultiEffect {
                        source: breakpointsContainer
                        anchors.fill: breakpointsContainer
                        paddingRect: Qt.rect(0, 0, breakpointsContainer.width, breakpointsContainer.height)
                        shadowEnabled: true
                        shadowBlur: 1.0
                        shadowOpacity: dialogShadow.visible ? 1.0 : defaultRectangleShadow
                        Behavior on shadowOpacity {
                            NumberAnimation {
                                duration: dialogShadow.consoleAnimation
                                easing.type: Easing.OutCubic
                            }
                        }
                    }*/
                }

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: paddingSmall
                    anchors.leftMargin: paddingSmall
                    height: (debuggerArea.usableHeight / 3) - paddingSmall

                    Rectangle {
                        id: backtracesContainer
                        anchors.fill: parent
                        radius: roundedCornersRadiusMedium
                        border.color: root.borderColor
                        border.width: 1
                        color: root.palette.base

                        Label {
                            anchors.fill: parent
                            anchors.margins: paddingSmall
                            text: qsTr("No frames available")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            readonly property bool visibility: backtracesListView.model.length === 0
                            visible: opacity > 0.0
                            opacity: visibility ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                        }

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

                            ScrollBar.vertical: TideScrollBar {
                                parent: backtracesListView
                            }

                            delegate: DebuggerListEntry {
                                readonly property var dbugger: root.dbugger
                                readonly property int frameIndex: modelData.frameIndex

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
                                onClicked: {
                                    dbugger.selectFrame(frameIndex)
                                }
                            }
                        }
                    }

                    /*MultiEffect {
                        source: backtracesContainer
                        anchors.fill: backtracesContainer
                        paddingRect: Qt.rect(0, 0, backtracesContainer.width, backtracesContainer.height)
                        shadowEnabled: true
                        shadowBlur: 1.0
                        shadowOpacity: dialogShadow.visible ? 1.0 : defaultRectangleShadow
                        Behavior on shadowOpacity {
                            NumberAnimation {
                                duration: dialogShadow.consoleAnimation
                                easing.type: Easing.OutCubic
                            }
                        }
                    }*/
                }

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: paddingSmall
                    anchors.leftMargin: paddingSmall
                    height: (debuggerArea.usableHeight / 3) - paddingSmall

                    Rectangle {
                        id: frameValuesContainer
                        anchors.fill: parent
                        color: root.palette.base
                        radius: roundedCornersRadiusMedium
                        border.color: root.borderColor
                        border.width: 1

                        Label {
                            anchors.fill: parent
                            anchors.margins: paddingSmall
                            text: qsTr("No values available")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            readonly property bool visibility: frameValuesListView.model.length === 0
                            visible: opacity > 0.0
                            opacity: visibility ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                        }

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

                            ScrollBar.vertical: TideScrollBar {
                                parent: frameValuesListView
                            }

                            delegate: DebuggerListEntry {
                                id: valueOrInstruction
                                visible: !modelData.partial
                                boldText: modelData.partial || modelData.name === undefined ?
                                              "" :
                                              modelData.type
                                text: modelData.partial || modelData.name === undefined ?
                                          modelData.value :
                                          modelData.name
                                detailText: modelData.partial || modelData.name === undefined ?
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
                                    z: paddedOverlayArea.contextMenuZ
                                }
                            }
                        }
                    }

                    /*MultiEffect {
                        source: frameValuesContainer
                        anchors.fill: frameValuesContainer
                        paddingRect: Qt.rect(0, 0, frameValuesContainer.width, frameValuesContainer.height)
                        shadowEnabled: true
                        shadowBlur: 1.0
                        shadowOpacity: dialogShadow.visible ? 1.0 : defaultRectangleShadow
                        Behavior on shadowOpacity {
                            NumberAnimation {
                                duration: dialogShadow.consoleAnimation
                                easing.type: Easing.OutCubic
                            }
                        }
                    }*/
                }
            }
        }

        SettingsDialog {
            id: settingsDialog
            width: mainView.settingsDialogWidth
            height: mainView.settingsDialogHeight
            anchors.centerIn: parent
            parent: paddedOverlayArea
            z: paddedOverlayArea.settingsZ
        }

        GitDialog {
            id: gitDialog
            width: mainView.settingsDialogWidth
            height: mainView.settingsDialogHeight
            anchors.centerIn: parent
            parent: paddedOverlayArea
            z: paddedOverlayArea.contextMenuZ
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
            property int spacesForTab : 0
            property int tabWidth: 4
            property bool autocomplete: true
            property bool autoformat: true
            property bool autoindent: true
            property bool blinkingCursor: true
            property int formatStyle : CppFormatter.LLVM
            property bool wiggleHints : true
            property bool wrapEditor : true
            property bool clearConsole: true
            property bool rubberDuck : false
            property bool fallbackInterpreter : false
            property int stackSize : 16
            property int heapSize : 256
            property int threads : 16
            property bool optimizations : platformProperties.supportsOptimizations
        }

        Component {
            id: sureDialogComponent

            TideDialog {
                title: qsTr("Are you sure?");
                modal: true
                anchors.centerIn: parent
                standardButtons: Dialog.Ok | Dialog.Cancel

                property var projectFile : null

                signal done()

                Label {
                    width: parent.width
                    text: qsTr("This will delete the selected files permanently.")
                }

                onRejected: {
                    done()
                }
            }
        }

        Component {
            id: bookmarkRemoveDialogComponent

            TideDialog {
                title: qsTr("Are you sure?");
                modal: true
                anchors.centerIn: parent
                standardButtons: Dialog.Ok | Dialog.Cancel

                property var projectFile : null

                signal done()

                Label {
                    width: parent.width
                    text: qsTr("This will remove the selected bookmark.")
                }

                onRejected: {
                    done()
                }
            }
        }

        Component {
            id: cloneDialogComponent
            TideDialog {
                title: qsTr("Clone project");
                modal: true
                anchors.centerIn: parent
                standardButtons: Dialog.Ok | Dialog.Cancel
                Component.onCompleted: {
                    imFixer.setupImEventFilter(projectUrl)
                    imFixer.setupImEventFilter(projectName)
                }

                signal done()

                Column {
                    width: parent.width
                    height: implicitHeight

                    TextField {
                        id: projectUrl
                        width: parent.width
                        placeholderText: qsTr("URL:")
                        focus: true
                        /*validator: RegularExpressionValidator {
                            regularExpression: /^(http|https|git):\/\//
                        }*/
                        onTextChanged: {
                            let newProjectName = ""
                            {
                                const crumbs = projectUrl.text.split('/');
                                if (crumbs.length > 0) {
                                    newProjectName = crumbs[crumbs.length - 1]
                                }
                            }
                            projectName.text = newProjectName
                        }
                    }
                    TextField {
                        id: projectName
                        width: parent.width
                        placeholderText: qsTr("Name:")
                        focus: true
                        validator: RegularExpressionValidator {
                            regularExpression: /^[a-zA-Z0-9_.-]*$/
                        }
                    }
                }

                onAccepted: {
                    git.clone(projectUrl.text, projectName.text)
                    done()
                }

                onRejected: {
                    done()
                }
            }
        }

        Component {
            id: createProjectDialogComponent
            TideDialog {
                title: qsTr("Create project");
                modal: true
                anchors.centerIn: parent
                standardButtons: Dialog.Ok | Dialog.Cancel
                Component.onCompleted: imFixer.setupImEventFilter(projectName)

                signal done()

                Column {
                    width: parent.width
                    height: implicitHeight
                    spacing: paddingSmall

                    TextField {
                        id: projectName
                        width: parent.width
                        placeholderText: qsTr("Name:")
                        focus: true
                        validator: RegularExpressionValidator {
                            regularExpression: /^[a-zA-Z0-9_.-]*$/
                        }
                    }

                    ComboBox {
                        id: projectTypeComboBox
                        model: ["Application", "Library" /*, "Tide plugin"*/]
                        width: parent.width
                        editable: false
                    }
                }

                onAccepted: {
                    if (projectName.text === "")
                        return

                    projectCreator.createProject(projectName.text,
                                                 projectTypeComboBox.currentIndex)
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
                title: qsTr("New file");
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
                    focus: true
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
                title: qsTr("New directory");
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
                    focus: true
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
            parent: paddedOverlayArea
            z: paddedOverlayArea.helpZ

            ScrollView {
                anchors.fill: parent
                contentWidth: -1
                HelpPage {
                    width: parent.width
                    height: implicitHeight
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: roundedCornersRadius
                }
            }
        }

        Rectangle {
            id: warningSign
            anchors.centerIn: parent
            width: 256
            height: 256
            opacity: 0.0
            visible: false
            clip: true
            border.color: flashingIcon.icon.color
            border.width: 1
            radius: roundedCornersRadiusMedium
            color: Qt.tint(root.palette.base, tintColor)
            parent: paddedOverlayArea
            z: paddedOverlayArea.warningZ
            readonly property color tintColor : Qt.rgba(flashingIcon.icon.color.r,
                                                        flashingIcon.icon.color.g,
                                                        flashingIcon.icon.color.b,
                                                        0.2)

            readonly property string iconWarning: Qt.resolvedUrl("qrc:/assets/xmark.circle@2x.png")
            readonly property string iconSuccess: Qt.resolvedUrl("qrc:/assets/checkmark.circle@2x.png")
            readonly property string iconPause: Qt.resolvedUrl("qrc:/assets/pause.circle@2x.png")
            readonly property string iconStop: Qt.resolvedUrl("qrc:/assets/stop.circle@2x.png")
            property string iconName : ""

            property var warningQueue : []

            onOpacityChanged: {
                if (opacity == 1.0)
                    hideTimer.start()
                else if (opacity == 0.0) {
                    if (warningQueue.length > 0) {
                        let obj = warningQueue.pop()
                        flashingIcon.icon.source = obj.icon
                        warningText.text = obj.msg
                        flashingIcon.icon.color = obj.color
                        mainBackgroundColorOverride = obj.color
                        opacity = 1.0
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            Behavior on y {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic; }
            }

            Timer {
                id: hideTimer
                interval: 1000
                onTriggered: {
                    warningSign.opacity = 0.0
                    colorResetTimer.restart()
                }
            }

            Timer {
                id: colorResetTimer
                interval: 2000
                onTriggered: {
                    mainBackgroundColorOverride = mainBackgroundDefaultColor
                }
            }

            function enqueue(msg, icon, color) {
                // Avoid enqueuing the same message twice or more times
                if (warningQueue.length > 0) {
                    let obj = warningQueue[warningQueue.length - 1]
                    if (obj.msg === msg &&
                            obj.icon === icon &&
                            obj.color === color) {
                        return;
                    }
                }
                warningQueue.push({ "msg" : msg, "icon" : icon, "color" : color });
            }

            function flashSuccess(text) {
                // TODO: Check queue whether the appropriate warning has already been shown

                if (opacity > 0.0) {
                    enqueue(text, iconSuccess, "teal")
                    return;
                }

                flashingIcon.icon.source = iconSuccess
                warningText.text = text
                flashingIcon.icon.color = "teal"
                mainBackgroundColorOverride = flashingIcon.icon.color
                opacity = 1.0
            }

            function flashWarning(text) {
                if (opacity > 0.0) {
                    enqueue(text, iconWarning, "darkred")
                    return;
                }

                flashingIcon.icon.source = iconWarning
                warningText.text = text
                flashingIcon.icon.color = "darkred"
                mainBackgroundColorOverride = flashingIcon.icon.color
                opacity = 1.0
            }

            function flashPause(text) {
                if (opacity > 0.0) {
                    enqueue(text, iconPause, "darkorange")
                    return;
                }

                flashingIcon.icon.source = iconPause
                warningText.text = text
                flashingIcon.icon.color = "darkorange"
                mainBackgroundColorOverride = flashingIcon.icon.color
                opacity = 1.0
            }

            function flashStop(text) {
                if (opacity > 0.0) {
                    enqueue(text, iconStop, "darkred")
                    return;
                }

                flashingIcon.icon.source = iconStop
                warningText.text = text
                flashingIcon.icon.color = "darkred"
                mainBackgroundColorOverride = flashingIcon.icon.color
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
                }
                Label {
                    id: warningText
                    color: Qt.rgba(flashingIcon.icon.color.r,
                                   flashingIcon.icon.color.g,
                                   flashingIcon.icon.color.b,
                                   1.0)
                    font.pixelSize: 20
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    text: ""
                }
            }
        }

        MultiEffect {
            parent: paddedOverlayArea
            z: paddedOverlayArea.warningZ
            anchors.centerIn: parent
            source: warningSign
            width: warningSign.width
            height: warningSign.height
            visible: warningSign.opacity > 0.0
            opacity: warningSign.opacity
            paddingRect: Qt.rect(0, 0, warningSign.width, warningSign.height)
            shadowEnabled: true
            shadowBlur: 1.0
            shadowOpacity: defaultRectangleShadow
            Behavior on shadowOpacity {
                NumberAnimation {
                    duration: dialogShadow.consoleAnimation
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Rubber Duck Layer
        Item {
            id: rubberDuckLayer
            anchors.fill: parent
            visible: settings.rubberDuck
            parent: paddedOverlayArea
            z: paddedOverlayArea.warningZ

            Image {
                id: rubberDuck
                source: Qt.resolvedUrl("qrc:/assets/RubberDuck.png")
                width: (implicitWidth / 2)
                height: (implicitHeight / 2)
                smooth: true

                Drag.active: dragArea.drag.active
                Drag.hotSpot.x: 10
                Drag.hotSpot.y: 10

                MouseArea {
                    id: dragArea
                    drag.target: parent
                    anchors.fill: parent
                }
            }

            property real saturation : dragArea.pressed ? 0.5 : 0.0
            Behavior on saturation {
                NumberAnimation {
                    duration: 500
                }
            }
            property color colorization : dragArea.pressed ? "mediumspringgreen" : "transparent"
            Behavior on colorization {
                ColorAnimation {
                    duration: 500
                    loops: Animation.Infinite
                }
            }

            MultiEffect {
                source: rubberDuck
                anchors.fill: rubberDuck
                saturation: parent.saturation
                brightness: parent.saturation
                blurEnabled: dragArea.pressed
                blur: 1.0
                blurMax: 64
                colorization: dragArea.pressed ? 0.5 : 0.0
                colorizationColor: parent.colorization
            }
        }

        // Loading splash screen
        Rectangle {
            property bool visibility: sysrootManager.installing
            anchors.fill: parent
            visible: opacity > 0.0
            color: "black"
            opacity: visibility ? 0.85 : 0.0
            parent: Overlay.overlay

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Label {
                id: preparationHint
                anchors.centerIn: parent
                width: parent.width - (paddingSmall * 2)
                font.pixelSize: 24
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

    Loader {
        id: inputPanel
        parent: Overlay.overlay
        readonly property bool inUse: platformProperties.usesBuiltinOsk && !uiIntegration.hasKeyboard
        z: paddedOverlayArea.inputPanelZ
        y: Qt.inputMethod.visible ? parent.height - inputPanel.height : parent.height
        anchors.left: parent.left
        anchors.right: parent.right
        source: inUse ? "VirtualKeyboard.qml" : ""
    }
}
