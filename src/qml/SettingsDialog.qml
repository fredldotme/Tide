import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TideDialog {
    id: settingsDialog

    readonly property bool paneHeight : implicitHeight
    readonly property alias sysrootComboBox: sysrootComboBox

    function show() {
        settingsDialog.open()
    }

    function hide() {
        settingsDialog.close()
    }

    Item {
        id: mainColumn
        anchors.fill: parent

        Item {
            id: consoleToolBar
            width: parent.width
            height: root.headerBarHeight

            RowLayout {
                anchors.fill: parent

                ToolButton {
                    text: qsTr("Categories")
                    font.bold: true
                    visible: !root.landscapeMode
                    leftPadding: paddingSmall
                    onClicked: {
                        categories.visibility = !categories.visibility
                    }
                }

                Label {
                    Layout.fillWidth: true
                    color: root.palette.text
                    text: qsTr("Settings")
                    elide: Text.ElideRight
                    font.bold: true
                    horizontalAlignment: Label.AlignHCenter
                    verticalAlignment: Label.AlignVCenter
                }

                ToolButton {
                    text: qsTr("Close")
                    font.bold: true
                    rightPadding: paddingSmall
                    onClicked: {
                        settingsDialog.hide()
                    }
                }
            }
        }

        Item {
            anchors {
                top: consoleToolBar.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            ListView {
                id: categories
                width: visibility ? 164 : 0
                height: parent.height
                spacing: paddingSmall
                currentIndex: 0
                interactive: false

                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutExpo
                    }
                }

                Connections {
                    target: root
                    function onLandscapeModeChanged() {
                        categories.visibility = root.landscapeMode
                    }
                }

                property bool visibility : root.landscapeMode

                model: ListModel {
                    ListElement {
                        category: qsTr("Appearance")
                        categoryIcon: "qrc:/assets/doc.plaintext@2x.png"
                    }
                    ListElement {
                        category: qsTr("Git")
                        categoryIcon: "qrc:/assets/arrow.triangle.branch@2x.png"
                    }
                    ListElement {
                        category: qsTr("Tools")
                        categoryIcon: "qrc:/assets/scissors@2x.png"
                    }
                    ListElement {
                        category: qsTr("Runtime")
                        categoryIcon: "qrc:/assets/figure.run@2x.png"
                    }
                    ListElement {
                        category: qsTr("Plugins")
                        categoryIcon: "qrc:/assets/powerplug@2x.png"
                    }
                    ListElement {
                        category: qsTr("Misc")
                        categoryIcon: "qrc:/assets/shippingbox@2x.png"
                    }
                }

                delegate: SettingsCategoryButton {
                    text: category
                    icon.source: Qt.resolvedUrl(categoryIcon)
                    width: categories.width
                    height: font.pixelSize + (paddingSmall * 2)
                    color: ListView.isCurrentItem ?
                               root.palette.active.button :
                               "transparent"
                    textColor: ListView.isCurrentItem ?
                                   root.palette.buttonText :
                                   root.palette.button
                    radius: roundedCornersRadiusSmall
                    font.pixelSize: 18
                    outline: false
                    onClicked: {
                        categories.currentIndex = index
                        categories.visibility = root.landscapeMode
                    }
                }

                ScrollIndicator.vertical: ScrollIndicator { }
            }

            StackLayout {
                anchors {
                    top: parent.top
                    left: categories.right
                    leftMargin: paddingMedium
                    right: parent.right
                    bottom: parent.bottom
                }
                currentIndex: categories.currentIndex

                // Appearance settings
                ScrollView {
                    width: parent.width
                    contentWidth: -1

                    Column {
                        width: childrenRect.width
                        height: childrenRect.height
                        spacing: paddingSmall
                        RowLayout {
                            Label {
                                text: qsTr("Font size")
                            }
                            ComboBox {
                                id: fontSizeComboBox
                                editable: false
                                model: availableFontSizes
                                currentIndex: settings.fontSize
                                onCurrentIndexChanged: {
                                    settings.fontSize = currentIndex
                                }
                            }
                        }
                        RowLayout {
                            Label {
                                text: qsTr("Tab width")
                            }
                            ComboBox {
                                editable: false
                                model: ListModel {
                                    ListElement {
                                        text: "1"
                                    }
                                    ListElement {
                                        text: "2"
                                    }
                                    ListElement {
                                        text: "3"
                                    }
                                    ListElement {
                                        text: "4"
                                    }
                                    ListElement {
                                        text: "5"
                                    }
                                    ListElement {
                                        text: "6"
                                    }
                                    ListElement {
                                        text: "7"
                                    }
                                    ListElement {
                                        text: "8"
                                    }
                                }
                                currentIndex: settings.tabWidth - 1
                                onCurrentIndexChanged: {
                                    settings.tabWidth = (currentIndex + 1)
                                }
                            }
                        }
                        RowLayout {
                            Label {
                                text: qsTr("Spaces per tab")
                            }
                            ComboBox {
                                editable: false
                                model: ListModel {
                                    ListElement {
                                        text: "Off"
                                    }
                                    ListElement {
                                        text: "1"
                                    }
                                    ListElement {
                                        text: "2"
                                    }
                                    ListElement {
                                        text: "3"
                                    }
                                    ListElement {
                                        text: "4"
                                    }
                                    ListElement {
                                        text: "5"
                                    }
                                    ListElement {
                                        text: "6"
                                    }
                                    ListElement {
                                        text: "7"
                                    }
                                    ListElement {
                                        text: "8"
                                    }
                                }
                                currentIndex: settings.spacesForTab
                                onCurrentIndexChanged: {
                                    settings.spacesForTab = currentIndex
                                }
                            }
                        }
                        Switch {
                            text: qsTr("Blinking cursor")
                            checked: settings.blinkingCursor
                            onCheckedChanged: {
                                settings.blinkingCursor = checked
                            }
                        }
                        Switch {
                            text: qsTr("Automatically indent new lines")
                            checked: settings.autoindent
                            onCheckedChanged: {
                                settings.autoindent = checked
                            }
                        }
                        Switch {
                            text: qsTr("Wrap code editor")
                            checked: settings.wrapEditor
                            onCheckedChanged: {
                                settings.wrapEditor = checked
                            }
                        }
                        Switch {
                            text: qsTr("Pop-out console")
                            checked: !settings.integratedConsole
                            onCheckedChanged: {
                                settings.integratedConsole = !checked
                            }
                        }
                    }
                }

                // Git
                ScrollView {
                    width: parent.width
                    contentWidth: -1

                    Column {
                        width: parent.width
                        height: implicitHeight
                        spacing: paddingSmall

                        RowLayout {
                            width: parent.width
                            Label {
                                text: qsTr("Name:")
                            }
                            TextField {
                                id: gitName
                                text: settings.gitName
                                onTextEdited: {
                                    settings.gitName = gitName.text
                                }

                                Layout.fillWidth: true
                            }
                        }
                        RowLayout {
                            width: parent.width
                            Label {
                                text: qsTr("Email:")
                            }
                            TextField {
                                id: gitEmail
                                text: settings.gitEmail
                                onTextEdited: {
                                    settings.gitEmail = gitEmail.text
                                }

                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // Tools
                ScrollView {
                    width: parent.width
                    contentWidth: -1

                    Column {
                        width: childrenRect.width
                        height: childrenRect.height
                        spacing: paddingSmall
                        Switch {
                            id: autocompleteSwitch
                            text: qsTr("Autocomplete (Shift+⌘+S)")
                            checked: settings.autocomplete
                            onCheckedChanged: {
                                settings.autocomplete = checked
                            }
                        }
                        Switch {
                            id: autoformatSwitch
                            text: qsTr("Formatter (Shift+⌘+F)")
                            checked: settings.autoformat
                            onCheckedChanged: {
                                settings.autoformat = checked
                            }
                        }
                        RowLayout {
                            enabled: settings.autoformat
                            Label {
                                text: qsTr("Formatting style")
                            }
                            ComboBox {
                                id: formatStyleComboBox
                                editable: false
                                model: ListModel {
                                    ListElement {
                                        text: "LLVM"
                                    }
                                    ListElement {
                                        text: "Google"
                                    }
                                    ListElement {
                                        text: "Chromium"
                                    }
                                    ListElement {
                                        text: "GNU"
                                    }
                                }
                                currentIndex: settings.formatStyle
                                onCurrentIndexChanged: {
                                    settings.formatStyle = currentIndex
                                }
                            }
                        }
                    }
                }

                // Runtime
                ScrollView {
                    id: runtimeView
                    width: parent.width

                    Column {
                        id: runtimeMainColumn
                        width: implicitWidth
                        height: implicitHeight
                        spacing: paddingSmall
                        RowLayout {
                            spacing: paddingMedium
                            Slider {
                                from: 1
                                to: 1024
                                value: settings.stackSize
                                onValueChanged: {
                                    settings.stackSize = value;
                                }
                            }
                            Label {
                                text: qsTr("Stack size (MB): ")
                            }
                            SpinBox {
                                id: stackSizeTextField
                                value: settings.stackSize
                                onValueChanged: {
                                    settings.stackSize = value
                                }
                                from: 1
                                to: 1024
                            }
                        }
                        RowLayout {
                            spacing: paddingMedium
                            Slider {
                                from: 1
                                to: 1024
                                value: settings.heapSize
                                onValueChanged: {
                                    settings.heapSize = value;
                                }
                            }
                            Label {
                                text: qsTr("Heap size (MB): ")
                            }
                            SpinBox {
                                id: heapSizeTextField
                                value: settings.heapSize
                                from: 1
                                to: 1024
                                onValueChanged: {
                                    settings.heapSize = value
                                }
                            }
                        }
                        RowLayout {
                            spacing: paddingMedium
                            Slider {
                                from: 1
                                to: 32
                                value: settings.threads
                                onValueChanged: {
                                    settings.threads = value;
                                }
                            }
                            Label {
                                text: qsTr("Thread count: ")
                            }
                            SpinBox {
                                id: threadsTextField
                                value: settings.threads
                                from: 1
                                to: 32
                                onValueChanged: {
                                    settings.threads = value;
                                }
                            }
                        }
                        Switch {
                            id: optSwitch
                            text: qsTr("AOT/JIT optimizations")
                            visible: platformProperties.supportsOptimizations
                            checked: settings.optimizations
                            onCheckedChanged: {
                                settings.optimizations = checked
                            }
                        }
                    }
                }

                // Plugins
                Item {
                    width: parent.width
                    height: parent.height

                    Column {
                        width: parent.width
                        anchors.centerIn: parent
                        visible: pluginManager.plugins.length === 0
                        spacing: paddingMedium
                        Label {
                            text: qsTr("No plugins found")
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        RowLayout {
                            width: implicitWidth
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: paddingSmall

                            TideButton {
                                text: qsTr("Reload plugins")
                                color: root.palette.button
                                onClicked: {
                                    pluginManager.reloadPlugins()
                                    hud.hudLabel.flashMessage("Plugins reloaded")
                                }
                            }
                            TideButton {
                                text: qsTr("Open Plugins folder")
                                color: root.palette.button
                                onClicked: {
                                    Qt.openUrlExternally(root.dirOpenProtocol + pluginManager.pluginsPath())
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        height: parent.height
                        spacing: 0
                        visible: pluginManager.plugins.length !== 0

                        ListView {
                            model: pluginManager.plugins
                            width: parent.width
                            height: parent.height
                            clip: true
                            spacing: paddingSmall
                            header: Component {
                                Row {
                                    spacing: paddingTiny
                                    ToolButton {
                                        text: qsTr("Reload plugins")
                                        visible: pluginManager.plugins.length !== 0
                                        onClicked: {
                                            pluginManager.reloadPlugins()
                                        }
                                    }
                                    ToolButton {
                                        text: qsTr("Open Plugins folder")
                                        onClicked: {
                                            Qt.openUrlExternally("shareddocuments://" + pluginManager.pluginsPath())
                                        }
                                    }
                                }
                            }

                            delegate: Column {
                                width: parent.width
                                height: implicitHeight
                                Label {
                                    text: qsTr("<b>Name:</b> ") + modelData.name
                                }
                                Label {
                                    text: qsTr("<b>Description:</b> ") + modelData.description
                                }
                            }
                        }
                    }
                }

                // Misc
                ScrollView {
                    width: parent.width
                    contentWidth: -1

                    Column {
                        width: childrenRect.width
                        height: childrenRect.height
                        spacing: paddingSmall

                        RowLayout {
                            Label {
                                text: qsTr("Sysroot:")
                            }
                            ComboBox {
                                id: sysrootComboBox
                                editable: false
                                model: ListModel {
                                    ListElement {
                                        text: "Without exceptions"
                                    }
                                    ListElement {
                                        text: "With exceptions"
                                    }
                                }
                                currentIndex: settings.sysrootType - 1
                                onCurrentIndexChanged: {
                                    settings.sysrootType = currentIndex + 1
                                }
                            }
                        }
                        Switch {
                            text: qsTr("Wiggle hints")
                            checked: settings.wiggleHints
                            onCheckedChanged: {
                                settings.wiggleHints = checked
                            }
                        }
                        Switch {
                            id: fallbackInterpreterSwitch
                            text: qsTr("Force debug interpeter during regular runs")
                            checked: settings.fallbackInterpreter
                            onCheckedChanged: {
                                settings.fallbackInterpreter = checked
                            }
                        }
                        Switch {
                            id: clearConsoleSwitch
                            text: qsTr("Clear console output on each run")
                            checked: settings.clearConsole
                            onCheckedChanged: {
                                settings.clearConsole = checked
                            }
                        }
                        Switch {
                            text: qsTr("Rubber duck debugging")
                            checked: settings.rubberDuck
                            onCheckedChanged: {
                                settings.rubberDuck = checked
                            }
                        }
                    }
                }
            }
        }
    }
}

