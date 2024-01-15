import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Column {
    id: itemRoot
    spacing: paddingSmall

    property alias color: labelControl.color
    property alias prefix: prefixLabelControl.text
    property alias text: labelControl.text
    property alias detail: detailsLabelControl.text
    property alias font: labelControl.font
    property alias elide: labelControl.elide
    property alias icon: iconControl.icon
    property bool flat: true
    property bool pressAnimation : true
    property bool longPressEnabled: true
    readonly property bool pressed: iconControl.pressed || prefixLabelControlMouseArea.pressed ||
                                    labelControlMouseArea.pressed || detailsLabelControlMouseArea.pressed

    signal clicked()
    signal pressAndHold()

    scale: pressed ? 0.9 : 1.0
    opacity: pressed || !enabled ? 0.5 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: labelControlMouseArea.pressAndHoldInterval
            easing.type: Easing.OutQuad
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 750
            easing.type: Easing.OutQuad
        }
    }

    Row {
        id: content
        width: implicitWidth
        spacing: paddingSmall
        Button {
            id: iconControl
            flat: itemRoot.flat
            width: implicitWidth
            onClicked: itemRoot.clicked()
            onPressAndHold: {
                if (!longPressEnabled) {
                    itemRoot.clicked()
                    return
                }
                itemRoot.pressAndHold()
            }
        }
        Row {
            width: implicitWidth
            spacing: paddingSmall
            Label {
                id: prefixLabelControl
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: labelControl.color
                font: labelControl.font
                opacity: 0.75
                width: implicitWidth
                MouseArea {
                    id: prefixLabelControlMouseArea
                    anchors.fill: parent
                    onClicked: itemRoot.clicked()
                    onPressAndHold: {
                        if (!longPressEnabled) {
                            itemRoot.clicked()
                            return
                        }
                        itemRoot.pressAndHold()
                    }
                }
            }

            Label {
                id: labelControl
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                MouseArea {
                    id: labelControlMouseArea
                    anchors.fill: parent
                    onClicked: itemRoot.clicked()
                    onPressAndHold: {
                        if (!longPressEnabled) {
                            itemRoot.clicked()
                            return
                        }
                        itemRoot.pressAndHold()
                    }
                }
            }
        }
    }

    Label {
        id: detailsLabelControl
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        color: labelControl.color
        font.styleName: labelControl.font.styleName
        font.bold: labelControl.font.bold
        font.pixelSize: labelControl.font.pixelSize - 6
        opacity: 0.5
        width: implicitWidth
        x: paddingSmall
        MouseArea {
            id: detailsLabelControlMouseArea
            anchors.fill: parent
            onClicked: itemRoot.clicked()
            onPressAndHold: {
                if (!longPressEnabled) {
                    itemRoot.clicked()
                    return
                }
                itemRoot.pressAndHold()
            }
        }
    }
}
