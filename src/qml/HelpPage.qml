import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    spacing: paddingMedium
    RowLayout {
        width: parent.width
        ToolButton {
            text: qsTr("Close")
            font.bold: true
            leftPadding: paddingMedium
            onClicked: {
                helpDialog.hide()
            }
        }
    }

    Image {
        Layout.alignment: Qt.AlignHCenter
        source: Qt.resolvedUrl("qrc:/assets/TideNaked@2x.png")
        Layout.preferredWidth: Math.min(128, parent.width)
        Layout.preferredHeight: width
    }

    Label {
        text: qsTr("The Tide IDE")
        font.pixelSize: 24
        font.bold: true
        wrapMode: Label.WrapAtWordBoundaryOrAnywhere
        Layout.alignment: Qt.AlignHCenter
    }

    Label {
        text: qsTr("Usage")
        font.pixelSize: 20
        font.bold: true
        wrapMode: Label.WrapAtWordBoundaryOrAnywhere
        Layout.alignment: Qt.AlignLeft
    }

    Label {
        text: qsTr("• Create a new project or import one from an outside app") + "\n" +
              qsTr("• Select a .pro file to enable project management") + "\n" +
              qsTr("• Build & run the project with the 'Play' button")+ "\n"
        font.pixelSize: 18
        wrapMode: Label.WrapAtWordBoundaryOrAnywhere
        Layout.preferredWidth: parent.width
        Layout.alignment: Qt.AlignLeft
    }

    Label {
        text: qsTr("Open files")
        font.pixelSize: 20
        font.bold: true
        wrapMode: Label.WrapAtWordBoundaryOrAnywhere
        Layout.preferredWidth: parent.width
        Layout.alignment: Qt.AlignLeft
    }

    Label {
        text: qsTr("Open files are listed in the botton right corner.") + "\n" +
              qsTr("The status of the file (active project, unsaved changes) is displayed below the file name.") + "\n" +
              qsTr("The active project is identified by a circle surrounding its hammer icon.") + "\n"
        font.pixelSize: 18
        wrapMode: Label.WrapAtWordBoundaryOrAnywhere
        Layout.preferredWidth: parent.width
        Layout.alignment: Qt.AlignLeft
    }

    Label {
        text: qsTr("Build & run")
        font.pixelSize: 20
        font.bold: true
        wrapMode: Label.WrapAtWordBoundaryOrAnywhere
        Layout.preferredWidth: parent.width
        Layout.alignment: Qt.AlignLeft
    }

    Label {
        text: qsTr("Simply pressing the 'Play' button builds and runs the project.") + "\n" +
              qsTr("Long-pressing the 'Play' button summons a context menu:") + "\n" +
              qsTr("• 'Clean' to remove build artifacts") + "\n" +
              qsTr("• 'Build' to compile the active project") + "\n" +
              qsTr("• 'Run' to run the active project") + "\n" +
              qsTr("• 'Show/Hide Console' to spawn/hide the console view") + "\n" +
              "\n" +
              qsTr("CLI apps run in the console view and can be manipulated via stdin/out/err.") + "\n" +
              qsTr("The console view additionally allows filtering app outputs and compiler warnings away from serious errors.") + "\n"
        font.pixelSize: 18
        wrapMode: Label.WrapAtWordBoundaryOrAnywhere
        Layout.preferredWidth: parent.width
        Layout.alignment: Qt.AlignLeft
    }

    Label {
        text: qsTr("Project format")
        font.pixelSize: 20
        font.bold: true
        wrapMode: Label.WrapAtWordBoundaryOrAnywhere
        Layout.preferredWidth: parent.width
        Layout.alignment: Qt.AlignLeft
    }

    Label {
        text: qsTr("The project file format is largely inspired by QMake.") + "\n" +
              "\n" +
              qsTr("As a very manageable subset of QMake it provides the following default variables:") + "\n" +
              qsTr("• 'PWD': Directory of the project file") + "\n" +
              qsTr("• 'OUT_PWD': Directory of the build artifacts") + "\n" +
              "\n" +
              qsTr("Mutable values:") + "\n" +
              qsTr("• 'TARGET' (required): Name of the project's binary") + "\n" +
              qsTr("• 'SOURCES': Source files (.c, .cpp) to compile") + "\n" +
              qsTr("• 'INCLUDEPATH': Directories to add to header search path") + "\n" +
              qsTr("• 'LIBS': Libraries (.a) to link") + "\n" +
              qsTr("• 'DEFINES': Definitions to set during compilation") + "\n" +
              qsTr("• 'QMAKE_CFLAGS': Additional C compile flags for clang") + "\n" +
              qsTr("• 'QMAKE_CXXFLAGS': Additional C++ compile flags for clang++") + "\n" +
              qsTr("• 'QMAKE_LDFLAGS': Additional link flags") + "\n"
        font.pixelSize: 18
        wrapMode: Label.WrapAtWordBoundaryOrAnywhere
        Layout.preferredWidth: parent.width
        Layout.alignment: Qt.AlignLeft
    }

    Button {
        text: qsTr("Get Tide example projects!")
        icon.source: Qt.resolvedUrl("qrc:/assets/link@2x.png")
        font.pixelSize: 18
        onClicked: {
            Qt.openUrlExternally("https://github.com/fredldotme/TideExamples")
        }
    }
    Button {
        text: qsTr("Get Tide source code!")
        icon.source: Qt.resolvedUrl("qrc:/assets/link@2x.png")
        font.pixelSize: 18
        onClicked: {
            Qt.openUrlExternally("https://github.com/fredldotme/Tide")
        }
    }

    // Create padding a label high
    Label {
        font.pixelSize: 18
        text: ""
    }
}