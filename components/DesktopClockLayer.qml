import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.services
import ".."
import "common"

// Desktop clock glued to wallpaper parallax (end-4 WidgetCanvas).
// Base position is free-draggable and stored in StateService so it survives reloads.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property string screenName: modelData && modelData.name ? modelData.name : ""

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "m3qs:desktop-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: clockHost
    }

    property date currentTime: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    // --- Parallax hitch: lockstep with wallpaper (no extra Behavior) ---
    // State is published per-screen by Wallpaper itself — do not wait on wallpaperManager.
    readonly property int _parallaxRev: GlobalStates.wallpaperParallaxRev
    readonly property var _parallax: {
        let _ = root._parallaxRev;
        return GlobalStates.wallpaperParallaxState(root.screenName);
    }
    readonly property bool parallaxOn: root._parallax ? !!root._parallax.enabled : false
    readonly property real widgetsFactor: root._parallax && root._parallax.widgetsFactor !== undefined ? root._parallax.widgetsFactor : 1.2
    readonly property real workspaceZoom: Math.max(1.0, root._parallax && root._parallax.zoom !== undefined ? root._parallax.zoom : 1.07)
    // end-4: factor = widgetsFactor / workspaceZoom
    readonly property real parallaxFactor: root.parallaxOn ? (root.widgetsFactor / root.workspaceZoom) : 0
    readonly property real wallpaperOffsetX: root._parallax ? root._parallax.x : 0
    readonly property real wallpaperOffsetY: root._parallax ? root._parallax.y : 0

    // --- Persisted base position (canvas space) ---
    readonly property string stateKey: "desktopClock." + (root.screenName || "default")
    property real baseX: -1
    property real baseY: -1
    property bool _loading: false

    function clampX(x, w) {
        return Math.max(0, Math.min(x, Math.max(0, root.width - w)));
    }
    function clampY(y, h) {
        return Math.max(0, Math.min(y, Math.max(0, root.height - h)));
    }

    function applyBasePosition() {
        if (_loading || dragArea.drag.active)
            return;
        if (root.width <= 0 || root.height <= 0)
            return;

        const w = Math.max(clockHost.width, 1);
        const h = Math.max(clockHost.height, 1);
        let x = root.baseX;
        let y = root.baseY;
        if (x < 0 || y < 0) {
            x = Config.anchorFallbackX(root.width, w);
            y = Config.anchorFallbackY(root.height, h);
        }
        clockHost.x = root.clampX(x, w);
        clockHost.y = root.clampY(y, h);
    }

    function loadPosition() {
        if (!StateService.initialized)
            return;

        _loading = true;
        let saved = StateService.get(root.stateKey, null);
        if (saved && typeof saved === "object" && typeof saved.x === "number" && typeof saved.y === "number") {
            root.baseX = saved.x;
            root.baseY = saved.y;
        } else {
            let lx = StateService.get("desktopClockX", -1);
            let ly = StateService.get("desktopClockY", -1);
            if (typeof lx === "number" && typeof ly === "number" && lx >= 0 && ly >= 0) {
                root.baseX = lx;
                root.baseY = ly;
            }
        }
        _loading = false;
        applyBasePosition();
    }

    function savePosition() {
        if (!StateService.initialized)
            return;
        StateService.set(root.stateKey, {
            "x": root.baseX,
            "y": root.baseY
        });
    }

    onWidthChanged: applyBasePosition()
    onHeightChanged: applyBasePosition()

    Component.onCompleted: {
        applyBasePosition();
        if (StateService.initialized)
            loadPosition();
    }

    Connections {
        target: StateService
        function onStateLoaded() {
            root.loadPosition();
        }
    }

    // Canvas tracks wallpaper offset in lockstep (no Behavior)
    Item {
        id: widgetCanvas
        width: parent.width
        height: parent.height
        x: root.wallpaperOffsetX * root.parallaxFactor
        y: root.wallpaperOffsetY * root.parallaxFactor

        Item {
            id: clockHost
            width: faceLoader.item ? Math.max(faceLoader.item.implicitWidth, 1) : 230
            height: faceLoader.item ? Math.max(faceLoader.item.implicitHeight, 1) : 230

            scale: dragArea.pressed ? 1.05 : 1.0
            Behavior on scale {
                enabled: Config.animationSpeed > 0
                NumberAnimation {
                    duration: 160 * Math.max(0.01, Config.animationSpeed)
                    easing.type: Easing.OutCubic
                }
            }

            Loader {
                id: faceLoader
                anchors.centerIn: parent
                sourceComponent: {
                    switch (Config.variant) {
                    case "scalloped":
                        return scallopedComponent;
                    case "pill":
                        return pillComponent;
                    case "world":
                        return worldComponent;
                    case "stacked":
                        return stackedComponent;
                    case "cookie":
                    default:
                        return cookieComponent;
                    }
                }
                onLoaded: {
                    if (item && item.hasOwnProperty("currentTime"))
                        item.currentTime = Qt.binding(function () {
                            return root.currentTime;
                        });
                    Qt.callLater(root.applyBasePosition);
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                cursorShape: Config.clockDraggable ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                enabled: Config.clockDraggable
                drag.target: clockHost
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 0
                drag.maximumX: Math.max(0, widgetCanvas.width - clockHost.width)
                drag.minimumY: 0
                drag.maximumY: Math.max(0, widgetCanvas.height - clockHost.height)
                drag.threshold: 4

                onReleased: {
                    clockHost.x = root.clampX(clockHost.x, clockHost.width);
                    clockHost.y = root.clampY(clockHost.y, clockHost.height);
                    root.baseX = clockHost.x;
                    root.baseY = clockHost.y;
                    root.savePosition();
                }
            }
        }
    }

    Component {
        id: cookieComponent
        CookieClock {}
    }
    Component {
        id: scallopedComponent
        ScallopedAnalogClock {}
    }
    Component {
        id: stackedComponent
        StackedDigitalClock {}
    }
    Component {
        id: pillComponent
        PillDigitalClock {}
    }
    Component {
        id: worldComponent
        WorldClock {}
    }
}
