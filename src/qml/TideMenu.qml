import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Menu {
    id: menuRoot
    background: MultiEffect {
        implicitWidth: menuRoot.contentItem.implicitWidth
        implicitHeight: menuRoot.contentItem.implicitHeight
        source: menuRoot.contentItem
        paddingRect: Qt.rect(0, 0, menuRoot.width, menuRoot.height)
        shadowBlur: 0.5
        shadowEnabled: true
    }
    contentItem: Rectangle {
        implicitWidth: menuItemListView.width
        implicitHeight: menuItemListView.height
        color: root.palette.base
        radius: roundedCornersRadius
        clip: true
        ListView {
            id: menuItemListView
            model: menuRoot.contentModel
            interactive: Window.window
                         ? contentHeight + menuRoot.topPadding + menuRoot.bottomPadding > Window.window.height
                         : false
            currentIndex: menuRoot.currentIndex
            width: 200
            height: contentHeight

            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }
}
