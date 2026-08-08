import QtQuick
import qs.modules.widgets.defaultview

Item {
    id: root

    implicitWidth: 700
    implicitHeight: 240

    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    property var player
    property bool isBottom: false

    MusicPanel {
        anchors.fill: parent
        player: root.player
        panelVisible: true
        isBottom: root.isBottom
    }
}
