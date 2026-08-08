import QtQuick
import QtQuick.Layouts
import ".."
import "common"

Item {
    id: root

    property date currentTime: new Date()
    property bool use24Hour: Config.use24Hour

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    property vector2d blurVelocity: Qt.vector2d(0, 0)

    property int _prevMin: -1
    onCurrentTimeChanged: {
        var m = currentTime.getMinutes()
        if (m !== _prevMin) {
            blurVelocity = Qt.vector2d(0, 0.06)
            _prevMin = m
        }
    }

    function formatForZone(zone) {
        try {
            var fmt = new Intl.DateTimeFormat("en-US", {
                hour: "numeric",
                minute: "2-digit",
                hour12: !use24Hour,
                timeZone: zone
            })
            return fmt.format(currentTime)
        } catch (e) {
            return Qt.formatDateTime(currentTime, use24Hour ? "HH:mm" : "h:mm AP")
        }
    }

    function getOffsetDetails(zone) {
        try {
            var targetStr = currentTime.toLocaleString("en-US", { timeZone: zone })
            var targetDate = new Date(targetStr)
            var localDate = currentTime

            if (isNaN(targetDate.getTime()))
                return { offset: "", day: "Today", isNight: false }

            // Offset rounded to nearest half-hour to match IANA tz semantics
            var diffHrs = Math.round((targetDate.getTime() - localDate.getTime()) / 1800000) / 2
            var offsetStr = diffHrs === 0 ? "Same time" : (diffHrs > 0 ? "+" : "") + diffHrs + "h"

            var targetDay = targetDate.getDate()
            var localDay = localDate.getDate()
            var dayStr = "Today"

            if (targetDate.getFullYear() > localDate.getFullYear() ||
                (targetDate.getFullYear() === localDate.getFullYear() && targetDate.getMonth() > localDate.getMonth()) ||
                (targetDate.getFullYear() === localDate.getFullYear() && targetDate.getMonth() === localDate.getMonth() && targetDay > localDay)) {
                dayStr = "Tomorrow"
            } else if (targetDate.getFullYear() < localDate.getFullYear() ||
                       (targetDate.getFullYear() === localDate.getFullYear() && targetDate.getMonth() < localDate.getMonth()) ||
                       (targetDate.getFullYear() === localDate.getFullYear() && targetDate.getMonth() === localDate.getMonth() && targetDay < localDay)) {
                dayStr = "Yesterday"
            }

            var hour = targetDate.getHours()
            return {
                offset: offsetStr,
                day: dayStr,
                isNight: (hour < 6 || hour >= 18)
            }
        } catch (e) {
            return { offset: "", day: "Today", isNight: false }
        }
    }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        spacing: 10

        TonalSurface {
            id: localCard
            Layout.fillWidth: true
            implicitWidth: 270
            implicitHeight: 88
            topLeftR: 24
            topRightR: 24
            bottomLeftR: 24
            bottomRightR: 24
            tone: Colors.primaryContainer
            outlineWidth: 0
            morphOnHover: true
            hoverRadius: 32

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: 2

                Text {
                    text: "LOCAL TIME"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.family: "Inter"
                    font.letterSpacing: 1.5
                    color: Colors.onPrimaryContainer
                    opacity: 0.65
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: Qt.formatDateTime(root.currentTime, root.use24Hour ? "HH:mm" : "h:mm AP")
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        font.family: "Inter"
                        font.letterSpacing: -0.5
                        font.features: ({ "tnum": 1 })
                        color: Colors.onPrimaryContainer
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: Qt.formatDateTime(root.currentTime, "ddd, MMM d")
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.family: "Inter"
                        color: Colors.onPrimaryContainer
                        opacity: 0.8
                    }
                }
            }
        }

        Repeater {
            model: Config.worldTimezones

            TonalSurface {
                id: zoneCard
                required property var modelData
                Layout.fillWidth: true
                implicitWidth: 270
                implicitHeight: 76
                topLeftR: 16
                topRightR: 16
                bottomLeftR: 16
                bottomRightR: 16
                tone: Colors.surfaceContainer
                morphOnHover: true
                hoverRadius: 24

                readonly property var offsetData: root.getOffsetDetails(modelData.zone)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: zoneCard.modelData.label
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.family: "Inter"
                            color: Colors.onSurface
                        }

                        Text {
                            text: zoneCard.offsetData.day + ", " + zoneCard.offsetData.offset + " " + (zoneCard.offsetData.isNight ? "night" : "day")
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.family: "Inter"
                            color: Colors.onSurfaceVariant
                            opacity: 0.8
                        }
                    }

                    Text {
                        text: root.formatForZone(zoneCard.modelData.zone)
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        font.family: "Inter"
                        font.letterSpacing: -0.4
                        font.features: ({ "tnum": 1 })
                        color: Colors.onSurface
                    }
                }
            }
        }
    }
}
