import QtQuick
import qs.modules.widgets.dashboard
import qs.modules.services
import qs.modules.globals

Item {
    id: root

    implicitWidth: 900
    implicitHeight: GlobalStates.dashboardCurrentTab === 2 ? 620 : (56 + 48 * 6)

    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    property string screenName: ""

    readonly property int leftPanelWidth: 270

    Dashboard {
        id: dashboardItem
        anchors.fill: parent
        leftPanelWidth: root.leftPanelWidth
        screenName: root.screenName

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Visibilities.setActiveModule("");
                event.accepted = true;
            } else if (event.key === Qt.Key_Space) {
                event.accepted = false;
            }
        }

        Component.onCompleted: {
            Qt.callLater(() => {
                forceActiveFocus();
            });
        }
    }
}
