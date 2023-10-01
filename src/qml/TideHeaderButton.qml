import QtQuick
import QtQuick.Controls

Item {
    id: headerButtonRoot

    scale: headerButtonIcon.pressed ? 0.9 : 1.0
    opacity: headerButtonIcon.pressed || !enabled ? 0.5 : 1.0

    width: height

    property alias source: headerButtonIcon.icon.source
    property alias color: headerButtonIcon.icon.color

    signal clicked();
    signal pressAndHold();

    Button {
        id: headerButtonIcon
        anchors.fill: parent
        flat: true
        topInset: 0
        topPadding: 0
        leftInset: 0
        leftPadding: 0
        rightInset: 0
        rightPadding: 0
        bottomInset: 0
        bottomPadding: 0
        icon.width: headerButtonRoot.width
        icon.height: headerButtonRoot.height
        onClicked: headerButtonRoot.clicked()
        onPressAndHold: headerButtonRoot.pressAndHold()
    }

    Behavior on scale {
        NumberAnimation {
            duration: 1000
            easing.type: Easing.OutQuad
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 750
            easing.type: Easing.OutQuad
        }
    }
}
