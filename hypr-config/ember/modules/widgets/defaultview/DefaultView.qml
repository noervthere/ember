import QtQuick
import QtQuick.Controls
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.services
import qs.modules.notch
import qs.modules.components
import qs.config

Item {
    id: root
    anchors.top: parent.top
    focus: false
    clip: true

    // Layout constants
    readonly property int notificationPadding: 16
    readonly property int notificationPaddingBottom: Config.notchTheme === "island" ? 20 : 16
    readonly property int notificationPaddingTop: 8

    // State
    readonly property bool hasActiveNotifications: Notifications.popupList.length > 0
    readonly property var activePlayer: MprisController.activePlayer
    property bool notchHovered: false
    property bool parentHoverActive: false
    property bool isNavigating: false

    // Position detection
    readonly property string notchPosition: Config.notchPosition ?? "top"
    readonly property bool isBottom: notchPosition === "bottom"

    HoverHandler {
        id: contentHoverHandler
    }

    readonly property bool _mouseOver: contentHoverHandler.hovered || notchHovered || parentHoverActive
    property bool _collapseKeepAlive: false

    readonly property bool expandedState: _mouseOver || isNavigating || Visibilities.playerMenuOpen || mediaHoverExpanded || _collapseKeepAlive

    property bool mediaHoverExpanded: false
    property bool _expansionLocked: false

    Timer {
        id: expansionLockTimer
        interval: Config.animDuration + 150
        onTriggered: _expansionLocked = false
    }

    Timer {
        id: mediaHoverTimer
        interval: 0
        running: expandedState && !_menuCooldown && activePlayer !== null && !hasActiveNotifications && !mediaHoverExpanded && !_collapseKeepAlive && !(Config.notch.disableHoverExpansion ?? false)
        onTriggered: {
            _expansionLocked = true;
            mediaHoverExpanded = true;
            expansionLockTimer.restart();
        }
    }

    // Detect mouse leave while expanded → start collapse morph (debounced to 300ms and locked during transition)
    Timer {
        id: collapseTimer
        interval: 20
        running: mediaHoverExpanded && !_expansionLocked && !_mouseOver && !isNavigating && !Visibilities.playerMenuOpen
        onTriggered: {
            _collapseKeepAlive = true;
            mediaHoverExpanded = false;
            collapseKeepAliveTimer.restart();
        }
    }

    // Keep notch visible until collapse animation finishes
    Timer {
        id: collapseKeepAliveTimer
        interval: Config.animDuration
        onTriggered: _collapseKeepAlive = false
    }

    onActivePlayerChanged: {
        if (!activePlayer) {
            mediaHoverExpanded = false;
            _collapseKeepAlive = false;
        }
    }

    // Reset hover expansion when any menu opens/closes
    Connections {
        target: Visibilities
        function onCurrentActiveModuleChanged() {
            if (Visibilities.currentActiveModule !== "") {
                // Menu opened — snap to compact
                root._resetHoverState();
            } else {
                // Menu closed — cooldown to prevent hover re-expansion during pop transition
                root._menuCooldown = true;
                menuCooldownTimer.restart();
            }
        }
    }

    property bool _skipAnimation: false
    property bool _menuCooldown: false

    Timer {
        id: menuCooldownTimer
        interval: Config.animDuration + 100
        onTriggered: _menuCooldown = false
    }

    function _resetHoverState() {
        _skipAnimation = true;
        _expansionLocked = false;
        mediaHoverExpanded = false;
        _collapseKeepAlive = false;
        mediaHoverTimer.stop();
        collapseTimer.stop();
        collapseKeepAliveTimer.stop();
        expansionLockTimer.stop();
        Qt.callLater(() => { _skipAnimation = false; });
    }

    property real mainRowMargin: 16

    Behavior on mainRowMargin {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    // Computed dimensions
    readonly property real mainRowContentWidth: 200 + userInfo.width + separator1.width + separator2.width + notifIndicator.width + (mainRow.spacing * 4) + mainRowMargin
    readonly property real mainRowHeight: Config.showBackground ? (Config.notchTheme === "island" ? 36 : 44) : (Config.notchTheme === "island" ? 36 : 40)
    readonly property real notificationMinWidth: expandedState ? 420 : 320
    readonly property real notificationContainerHeight: notificationView.implicitHeight + notificationPaddingTop + notificationPaddingBottom

    // Music panel dimensions
    readonly property real musicPanelWidth: 760
    readonly property real musicPanelHeight: 270

    readonly property real collapsedWidth: hasActiveNotifications ? Math.max(notificationMinWidth + (notificationPadding * 2), mainRowContentWidth) : mainRowContentWidth
    readonly property real collapsedHeight: hasActiveNotifications ? mainRowHeight + notificationContainerHeight : mainRowHeight

    implicitWidth: Math.round(mediaHoverExpanded ? musicPanelWidth : collapsedWidth)
    implicitHeight: Math.round(mediaHoverExpanded ? musicPanelHeight : collapsedHeight)

    Keys.onPressed: event => {
        if (expandedState && activePlayer) {
            if (event.key === Qt.Key_Space) {
                activePlayer.togglePlaying();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left && activePlayer.canSeek) {
                activePlayer.position = Math.max(0, activePlayer.position - 10);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right && activePlayer.canSeek) {
                activePlayer.position = Math.min(activePlayer.length, activePlayer.position + 10);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up && activePlayer.canGoPrevious) {
                activePlayer.previous();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down && activePlayer.canGoNext) {
                activePlayer.next();
                event.accepted = true;
            }
        }
    }

    Item {
        id: innerContentContainer
        anchors.centerIn: parent
        width: typeof notchContainer !== "undefined" ? Math.min(root.implicitWidth, notchContainer.implicitWidth - notchContainer.totalCornerWidth) : root.implicitWidth
        height: typeof notchContainer !== "undefined" ? Math.min(root.implicitHeight, notchContainer.implicitHeight) : root.implicitHeight
        clip: true

        // mainRow container (compact mode)
        Row {
            id: mainRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: isBottom ? undefined : parent.top
            anchors.bottom: isBottom ? parent.bottom : undefined
            width: parent.width - mainRowMargin
            height: mainRowHeight
            spacing: 4
            z: 2
            visible: opacity > 0
            opacity: mediaHoverExpanded ? 0.0 : 1.0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }

            UserInfo {
                id: userInfo
                anchors.verticalCenter: parent.verticalCenter
            }

            Separator {
                id: separator1
                vert: true
                anchors.verticalCenter: parent.verticalCenter
            }

            CompactPlayer {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - userInfo.width - separator1.width - separator2.width - notifIndicator.width - (parent.spacing * 4)
                height: 32
                player: activePlayer
                notchHovered: expandedState
            }

            Separator {
                id: separator2
                vert: true
                anchors.verticalCenter: parent.verticalCenter
            }

            NotificationIndicator {
                id: notifIndicator
                anchors.verticalCenter: parent.verticalCenter
            }
        }



        // Music panel (expanded hover mode)
        Loader {
            id: musicPanelLoader
            anchors.fill: parent
            clip: true
            active: activePlayer !== null
            visible: opacity > 0
            opacity: mediaHoverExpanded ? 1.0 : 0.0
            scale: mediaHoverExpanded ? 1.0 : 0.8
            transformOrigin: root.isBottom ? Item.Bottom : Item.Top

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
            }

            Behavior on scale {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }

            sourceComponent: Component {
                MusicPanel {
                    player: root.activePlayer
                    panelVisible: root.mediaHoverExpanded
                    isBottom: root.isBottom
                }
            }
        }

        // Notification container with its own padding
        Item {
            id: notificationContainer
            width: parent.width
            height: hasActiveNotifications ? notificationContainerHeight : 0
            visible: hasActiveNotifications
            
            // Position relative to mainRow
            anchors.top: isBottom ? undefined : mainRow.bottom
            anchors.bottom: isBottom ? mainRow.top : undefined
            
            NotchNotificationView {
                id: notificationView
                anchors.fill: parent
                anchors.topMargin: notificationPaddingTop
                anchors.leftMargin: notificationPadding
                anchors.rightMargin: notificationPadding
                anchors.bottomMargin: notificationPaddingBottom
                visible: hasActiveNotifications
                opacity: visible ? 1 : 0
                notchHovered: expandedState
                onIsNavigatingChanged: root.isNavigating = isNavigating

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }
    }
}