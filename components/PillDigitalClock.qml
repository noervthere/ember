import QtQuick
import QtQuick.Layouts
import ".."
import "common"

Item {
    id: root

    property date currentTime: new Date()
    property bool use24Hour: Config.use24Hour

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    readonly property string hoursText: Qt.formatDateTime(currentTime, use24Hour ? "HH" : "h")
    readonly property string minutesText: Qt.formatDateTime(currentTime, "mm")
    readonly property string ampmText: use24Hour ? "" : Qt.formatDateTime(currentTime, "AP")
    readonly property string dateText: Qt.formatDateTime(currentTime, "ddd, MMM d")

    property vector2d blurVelocity: Qt.vector2d(0, 0)

    property int _prevMin: -1
    onCurrentTimeChanged: {
        var m = currentTime.getMinutes()
        if (m !== _prevMin) {
            blurVelocity = Qt.vector2d(0.08, 0.02)
            _prevMin = m
        }
    }

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        spacing: 12

        RowLayout {
            id: pillRow
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Rectangle {
                id: hourPill
                Layout.preferredHeight: 56
                Layout.preferredWidth: hourRow.width + 32
                radius: height / 2
                color: Colors.surfaceContainer

                Behavior on Layout.preferredWidth { SpringBehavior {} }

                Row {
                    id: hourRow
                    anchors.centerIn: parent
                    spacing: 0

                    Digit {
                        digit: root.hoursText.length > 0 ? root.hoursText.charAt(0) : " "
                        textColor: Colors.onSurface
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        font.family: "Inter"
                    }
                    Digit {
                        digit: root.hoursText.length > 1 ? root.hoursText.charAt(1) : (root.hoursText.length === 1 ? root.hoursText.charAt(0) : " ")
                        textColor: Colors.onSurface
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        font.family: "Inter"
                    }
                }
            }

            Rectangle {
                id: minutePill
                Layout.preferredHeight: 56
                Layout.preferredWidth: minuteRow.width + 32
                radius: height / 2
                color: Colors.primaryContainer

                Behavior on Layout.preferredWidth { SpringBehavior {} }

                Row {
                    id: minuteRow
                    anchors.centerIn: parent
                    spacing: 0

                    Digit {
                        digit: root.minutesText.length > 0 ? root.minutesText.charAt(0) : " "
                        textColor: Colors.onPrimaryContainer
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        font.family: "Inter"
                    }
                    Digit {
                        digit: root.minutesText.length > 1 ? root.minutesText.charAt(1) : (root.minutesText.length === 1 ? root.minutesText.charAt(0) : " ")
                        textColor: Colors.onPrimaryContainer
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        font.family: "Inter"
                    }
                }
            }

            Rectangle {
                id: ampmPill
                Layout.preferredHeight: 56
                Layout.preferredWidth: ampmLabel.implicitWidth + 24
                radius: height / 2
                color: Colors.surfaceContainerHigh
                visible: !root.use24Hour && root.ampmText !== ""

                Behavior on Layout.preferredWidth { SpringBehavior {} }

                Text {
                    id: ampmLabel
                    anchors.centerIn: parent
                    text: root.ampmText
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    font.family: "Inter"
                    color: Colors.onSurfaceVariant
                }
            }
        }

        TonalSurface {
            id: datePill
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: dateLabel.implicitWidth + 24
            implicitHeight: 28
            topLeftR: 14
            topRightR: 14
            bottomLeftR: 14
            bottomRightR: 14
            tone: Colors.surfaceContainerHigh
            outlineWidth: 0
            morphOnHover: true
            hoverRadius: 18

            Text {
                id: dateLabel
                anchors.centerIn: parent
                text: root.dateText.toUpperCase()
                font.pixelSize: 11
                font.weight: Font.Bold
                font.family: "Inter"
                font.letterSpacing: 0.8
                color: Colors.onSurfaceVariant
            }
        }
    }
}
