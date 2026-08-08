pragma Singleton
import QtQuick

// Desktop-clock face settings (m3qs module).
// Position is persisted via StateService from the clock layer — not here —
// because shell.qml also imports qs.config as Config and would shadow any
// FileView-based saver on this singleton.
QtObject {
    id: config

    // "cookie" | "scalloped" | "pill" | "world" | "stacked"
    property string variant: "cookie"
    property string theme: "matugen"
    property real radiusScale: 1.0
    property real animationSpeed: 1.0
    property bool use24Hour: false

    // Fallback placement when no saved coords exist yet
    property int marginTop: 60
    property int marginLeft: 60
    property int marginRight: 60
    property int marginBottom: 60
    property string anchorPosition: "topLeft"

    property bool clockDraggable: true

    property var worldTimezones: [
        { label: "New York", zone: "America/New_York" },
        { label: "London",   zone: "Europe/London" },
        { label: "Tokyo",    zone: "Asia/Tokyo" }
    ]

    property int heroFontSize: 112
    property int heroFontSizeAnalog: 22

    function anchorFallbackX(screenWidth, clockWidth) {
        const pos = (config.anchorPosition || "").toLowerCase();
        if (pos === "center")
            return Math.max(0, (screenWidth - clockWidth) / 2);
        if (pos.indexOf("right") >= 0)
            return Math.max(0, screenWidth - clockWidth - config.marginRight);
        return Math.max(0, config.marginLeft);
    }

    function anchorFallbackY(screenHeight, clockHeight) {
        const pos = (config.anchorPosition || "").toLowerCase();
        if (pos === "center")
            return Math.max(0, (screenHeight - clockHeight) / 2);
        if (pos.indexOf("bottom") >= 0)
            return Math.max(0, screenHeight - clockHeight - config.marginBottom);
        return Math.max(0, config.marginTop);
    }
}
