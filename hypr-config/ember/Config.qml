pragma Singleton
import QtQuick

QtObject {
    id: config

    property string variant: "pill"
    property string theme: "matugen"
    property real radiusScale: 1.0
    property real animationSpeed: 1.0
    property bool use24Hour: false

    property int marginTop: 60
    property int marginLeft: 60
    property int marginRight: 60
    property int marginBottom: 60

    property string anchorPosition: "topleft"

    property var worldTimezones: [
        { label: "New York", zone: "America/New_York" },
        { label: "London",   zone: "Europe/London" },
        { label: "Tokyo",    zone: "Asia/Tokyo" }
    ]

    property int heroFontSize: 112
    property int heroFontSizeAnalog: 22
}
