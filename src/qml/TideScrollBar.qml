import QtQuick.Controls

ScrollBar {
    hoverEnabled: true
    orientation: Qt.Vertical

    topPadding: orientation === Qt.Vertical ? roundedCornersRadiusMedium : 0
    bottomPadding: orientation === Qt.Vertical ? roundedCornersRadiusMedium : 0
    leftPadding: orientation === Qt.Vertical ? 0 : roundedCornersRadiusMedium
    rightPadding: orientation === Qt.Vertical ? 0 : roundedCornersRadiusMedium

    anchors.top: orientation === Qt.Vertical ? parent.top : top
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.left: orientation === Qt.Vertical ? left : parent.left

    policy: ScrollBar.AsNeeded
    size: (parent.height / parent.implicitHeight)
}
