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
   property string currentPanelMode: activePlayer !== null ? "music" : "search"
    readonly property bool isSearchHoverExpanded: mediaHoverExpanded && currentPanelMode === "search"

    function togglePanelMode() {
        if (activePlayer !== null) {
            currentPanelMode = (currentPanelMode === "music") ? "search" : "music";
        } else {
            currentPanelMode = "search";
        }
    }

   readonly property bool canExpandOnHover: (activePlayer !== null) || (Config.notch.idleHoverOpensSearch ?? true)

    Timer {
        id: expansionLockTimer
        interval: Config.animDuration + 150
        onTriggered: _expansionLocked = false
    }

    Timer {
        id: mediaHoverTimer
        interval: 0
        running: expandedState && !_menuCooldown && canExpandOnHover && !hasActiveNotifications && !mediaHoverExpanded && !_collapseKeepAlive && !(Config.notch.disableHoverExpansion ?? false)
        onTriggered: {
            _expansionLocked = true;
             currentPanelMode = activePlayer !== null ? "music" : "search";
            if (typeof panelTrainContainer !== "undefined") {
                panelTrainContainer.trainTrackX = currentPanelMode === "music" ? panelTrainContainer.musicX : panelTrainContainer.searchX;
            }
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
        if (!activePlayer && currentPanelMode === "music") {
            currentPanelMode = "search";
        }
    }

    // Reset hover expansion when any menu opens/closes
    Connections {
        target: Visibilities
        function onCurrentActiveModuleChanged() {
            root._resetHoverState();
            root._menuCooldown = true;
            if (Visibilities.currentActiveModule !== "") {
                // Menu opened — keep cooldown active while open
                menuCooldownTimer.stop();
            } else {
                // Menu closed — 500ms split second delay before allowing hover detection again
                menuCooldownTimer.restart();
            }
        }
    }

    property bool _skipAnimation: false
    property bool _menuCooldown: false

    Timer {
        id: menuCooldownTimer
        interval: Math.max(500, (Config.animDuration || 300) + 200)
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
        // Rectangular clip only; rounded masking is handled by Notch.stackContainer
        // so train slides stay inside the island radii.
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



        // Side-by-side Train Container for MusicPanel (0) and EmberSearchPanel (1)
        Item {
            id: panelTrainContainer
            anchors.fill: parent
            clip: true
            visible: opacity > 0
            opacity: root.mediaHoverExpanded ? 1.0 : 0.0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
            }

            readonly property real spacing: 16
            readonly property real panelWidth: 760
            readonly property real musicX: 0
            readonly property real searchX: -(panelWidth + spacing)

            property real trainTrackX: root.currentPanelMode === "music" ? musicX : searchX
            property real dragStartX: 0

            NumberAnimation {
                id: trainSnapAnim
                target: panelTrainContainer
                property: "trainTrackX"
                duration: Config.animDuration > 0 ? Config.animDuration : 350
                easing.type: Easing.OutQuart
            }

            function animateToX(newX) {
                trainSnapAnim.stop();
                trainSnapAnim.from = panelTrainContainer.trainTrackX;
                trainSnapAnim.to = newX;
                trainSnapAnim.start();
            }

            // Sync position when mode changes outside drag (e.g. initial hover expand)
            Connections {
                target: root
                function onCurrentPanelModeChanged() {
                    if (!panelSwipeHandler.active) {
                        let target = root.currentPanelMode === "music" ? panelTrainContainer.musicX : panelTrainContainer.searchX;
                        panelTrainContainer.animateToX(target);
                    }
                }
            }

            // The continuous train track item holding both panels side-by-side
            Item {
                id: trainTrack
                width: (panelTrainContainer.panelWidth * 2) + panelTrainContainer.spacing
                height: parent.height
                x: panelTrainContainer.trainTrackX

                // 1. MusicPanel (Carriage 0, x: 0)
                Item {
                    x: 0
                    width: panelTrainContainer.panelWidth
                    height: parent.height

                    Loader {
                        id: musicPanelLoader
                        anchors.fill: parent
                        active: root.mediaHoverExpanded
                        sourceComponent: Component {
                            MusicPanel {
                                player: root.activePlayer
                                panelVisible: root.mediaHoverExpanded
                                isBottom: root.isBottom
                            }
                        }
                    }
                }

                // 2. EmberSearchPanel (Carriage 1, x: panelWidth + spacing)
                Item {
                    x: panelTrainContainer.panelWidth + panelTrainContainer.spacing
                    width: panelTrainContainer.panelWidth
                    height: parent.height

                    Loader {
                        id: emberSearchLoader
                        anchors.fill: parent
                        active: root.mediaHoverExpanded
                        sourceComponent: Component {
                            EmberSearchPanel {
                                panelVisible: root.mediaHoverExpanded
                                isBottom: root.isBottom
                            }
                        }
                    }
                }
            }
        }

        // Horizontal Drag handler for live 1:1 train scrolling
        DragHandler {
            id: panelSwipeHandler
            target: null
            enabled: root.mediaHoverExpanded
            xAxis.enabled: true
            yAxis.enabled: false

            onActiveChanged: {
                if (active) {
                    trainSnapAnim.stop();
                    panelTrainContainer.dragStartX = panelTrainContainer.trainTrackX;
                } else {
                    let totalDrag = panelTrainContainer.trainTrackX - panelTrainContainer.dragStartX;
                    let targetMode = root.currentPanelMode;
                    if (totalDrag < -40) {
                        targetMode = "search";
                    } else if (totalDrag > 40) {
                        if (root.activePlayer !== null) {
                            targetMode = "music";
                        } else {
                            targetMode = "search";
                        }
                    }
                    root.currentPanelMode = targetMode;
                    let targetX = targetMode === "music" ? panelTrainContainer.musicX : panelTrainContainer.searchX;
                    panelTrainContainer.animateToX(targetX);
                }
            }

            onTranslationChanged: {
                if (active) {
                    let newX = panelTrainContainer.dragStartX + translation.x;
                    if (root.activePlayer === null && newX > panelTrainContainer.searchX) {
                        newX = panelTrainContainer.searchX;
                    }
                    panelTrainContainer.trainTrackX = newX;
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