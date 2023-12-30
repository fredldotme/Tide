import QtQuick
import QtQuick.Controls
import QtQuick.Effects

ComboBox {
    id: comboBox
    background: MultiEffect {
        implicitWidth: 200
        implicitHeight: comboBox.contentItem.implicitHeight
        source: comboBox.contentItem
        paddingRect: Qt.rect(0, 0, comboBox.width, comboBox.height)
        shadowBlur: 0.5
        shadowEnabled: true
    }
    contentItem: Rectangle {
        z: comboBox.z + 1
        implicitWidth: 200
        implicitHeight: menuItemListView.height
        color: root.palette.window
        radius: roundedCornersRadius
        clip: true
        ListView {
            id: menuItemListView
            model: comboBox.contentModel
            interactive: Window.window
                         ? contentHeight + comboBox.topPadding + comboBox.bottomPadding > Window.window.height
                         : false
            currentIndex: comboBox.currentIndex
            width: parent.width
            height: contentHeight

            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }
}
