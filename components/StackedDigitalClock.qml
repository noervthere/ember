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

    readonly property string hoursText: Qt.formatDateTime(currentTime, use24Hour ? "HH" : "hh")
    readonly property string minutesText: Qt.formatDateTime(currentTime, "mm")
    readonly property string dateText: Qt.formatDateTime(currentTime, "ddd, MMM d")

    property vector2d blurVelocity: Qt.vector2d(0, 0)

    property int _prevMin: -1
    onCurrentTimeChanged: {
        var m = currentTime.getMinutes()
        if (m !== _prevMin) {
            blurVelocity = Qt.vector2d(0, 0.1)
            _prevMin = m
        }
    }

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        spacing: -12

        Row {
            id: hoursRow
            Layout.alignment: Qt.AlignHCenter
            spacing: -Config.heroFontSize * 0.03

            property string text: root.hoursText
            onTextChanged: bounceH.restart()

            Digit {
                digit: hoursRow.text.length > 0 ? hoursRow.text.charAt(0) : " "
                textColor: Colors.onSurface
                font.pixelSize: Config.heroFontSize
                font.weight: Font.Black
                font.family: "Inter"
                font.letterSpacing: -Config.heroFontSize * 0.025
            }
            Digit {
                digit: hoursRow.text.length > 1 ? hoursRow.text.charAt(1) : " "
                textColor: Colors.onSurface
                font.pixelSize: Config.heroFontSize
                font.weight: Font.Black
                font.family: "Inter"
                font.letterSpacing: -Config.heroFontSize * 0.025
            }

            SequentialAnimation {
                id: bounceH
                NumberAnimation { target: hoursRow; property: "scale"; to: 0.94; duration: 80 * Config.animationSpeed; easing.type: Easing.InQuad }
                NumberAnimation { target: hoursRow; property: "scale"; to: 1.0; duration: 350 * Config.animationSpeed; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
            }
        }

        Row {
            id: minutesRow
            Layout.alignment: Qt.AlignHCenter
            spacing: -Config.heroFontSize * 0.03

            property string text: root.minutesText
            onTextChanged: bounceM.restart()

            Digit {
                digit: minutesRow.text.length > 0 ? minutesRow.text.charAt(0) : " "
                textColor: Colors.primary
                font.pixelSize: Config.heroFontSize
                font.weight: Font.Black
                font.family: "Inter"
                font.letterSpacing: -Config.heroFontSize * 0.025
            }
            Digit {
                digit: minutesRow.text.length > 1 ? minutesRow.text.charAt(1) : " "
                textColor: Colors.primary
                font.pixelSize: Config.heroFontSize
                font.weight: Font.Black
                font.family: "Inter"
                font.letterSpacing: -Config.heroFontSize * 0.025
            }

            SequentialAnimation {
                id: bounceM
                NumberAnimation { target: minutesRow; property: "scale"; to: 0.94; duration: 80 * Config.animationSpeed; easing.type: Easing.InQuad }
                NumberAnimation { target: minutesRow; property: "scale"; to: 1.0; duration: 350 * Config.animationSpeed; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
            }
        }

        TonalSurface {
            id: datePill
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            implicitWidth: dateLabel.implicitWidth + 32
            implicitHeight: 34
            topLeftR: 17
            topRightR: 17
            bottomLeftR: 17
            bottomRightR: 17
            tone: Colors.primaryContainer
            outlineWidth: 0
            morphOnHover: true
            hoverRadius: 24

            Text {
                id: dateLabel
                anchors.centerIn: parent
                text: root.dateText
                font.pixelSize: 13
                font.weight: Font.Bold
                font.family: "Inter"
                font.letterSpacing: 0.3
                color: Colors.onPrimaryContainer
            }
        }
    }
}
