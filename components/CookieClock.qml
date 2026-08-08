import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import ".."
import "common"

// Desktop cookie clock — port of end-4's CookieClock aesthetic,
// wired to ember Colors / Config and the shared currentTime binding.
Item {
    id: root

    property date currentTime: new Date()
    property bool use24Hour: Config.use24Hour

    // Visual tuning (end-4 cookie defaults)
    property real implicitSize: 230
    property int sides: 14
    property string dialStyle: "full"          // "dots" | "numbers" | "full" | "none"
    property string hourHandStyle: "fill"      // "classic" | "fill" | "hollow" | "hide"
    property string minuteHandStyle: "medium"  // "classic" | "thin" | "medium" | "bold" | "hide"
    property string secondHandStyle: "dot"     // "dot" | "line" | "classic" | "hide"
    property string dateStyle: "bubble"        // "bubble" | "rect" | "border" | "hide"
    property bool timeIndicators: true
    property bool hourMarks: false
    property bool constantlyRotate: false

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    readonly property int clockHour: currentTime.getHours() % 12
    readonly property int clockMinute: currentTime.getMinutes()
    readonly property int clockSecond: currentTime.getSeconds()
    readonly property string hoursText: Qt.formatDateTime(currentTime, use24Hour ? "HH" : "hh")
    readonly property string minutesText: Qt.formatDateTime(currentTime, "mm")
    readonly property string amPmText: use24Hour ? "" : Qt.formatDateTime(currentTime, "AP")

    // Colors (end-4 mixes primary/secondary into the cookie face)
    readonly property color colShadow: Qt.rgba(0, 0, 0, 0.35)
    readonly property color colBackground: Colors.primaryContainer
    readonly property color colOnBackground: mix(Colors.secondary, Colors.primaryContainer, 0.15)
    readonly property color colBackgroundInfo: mix(Colors.primary, Colors.primaryContainer, 0.55)
    readonly property color colHourHand: Colors.primary
    readonly property color colMinuteHand: Colors.tertiary
    readonly property color colSecondHand: Colors.primary

    property vector2d blurVelocity: Qt.vector2d(0, 0)
    property int _prevSec: -1
    onCurrentTimeChanged: {
        var s = currentTime.getSeconds();
        if (s !== _prevSec) {
            var rad = ((s * 6) - 90) * Math.PI / 180;
            blurVelocity = Qt.vector2d(0.08 * Math.cos(rad), 0.08 * Math.sin(rad));
            _prevSec = s;
        }
    }

    function mix(c1, c2, t) {
        var a = Qt.color(c1);
        var b = Qt.color(c2);
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            a.a + (b.a - a.a) * t
        );
    }

    // Soft drop shadow under the cookie face
    Rectangle {
        id: shadowCast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 5
        width: root.implicitSize * 0.88
        height: width
        radius: width / 2
        color: root.colShadow
        opacity: 0.4
        z: -1
        scale: 0.96
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.55
            blurMax: 28
            shadowEnabled: false
        }
    }

    // Cookie body (sine-wave scalloped disc, end-4 SineCookie style)
    Item {
        id: cookieFace
        anchors.fill: parent
        z: 0

        property real shapeRotation: 0

        FrameAnimation {
            running: root.constantlyRotate
            onTriggered: cookieFace.shapeRotation += 0.05
        }

        Shape {
            id: cookieShape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true

            ShapePath {
                strokeWidth: 0
                fillColor: root.colBackground
                PathPolyline {
                    path: {
                        var points = [];
                        var cx = cookieShape.width / 2;
                        var cy = cookieShape.height / 2;
                        var steps = 360;
                        var amplitude = root.implicitSize / 50;
                        var radius = root.implicitSize / 2 - amplitude;
                        var sides = Math.max(3, root.sides);
                        for (var i = 0; i <= steps; i++) {
                            var angle = (i / steps) * 2 * Math.PI;
                            var rotatedAngle = angle * sides + Math.PI / 2 + cookieFace.shapeRotation;
                            var wave = Math.sin(rotatedAngle) * amplitude;
                            points.push(Qt.point(
                                Math.cos(angle) * (radius + wave) + cx,
                                Math.sin(angle) * (radius + wave) + cy
                            ));
                        }
                        return points;
                    }
                }
            }
        }

        Behavior on opacity {
            enabled: Config.animationSpeed > 0
            NumberAnimation {
                duration: 200 * Config.animationSpeed
            }
        }
    }

    // Dial marks around the rim
    Item {
        id: dialMarks
        anchors.fill: parent
        anchors.margins: 10
        z: 1
        visible: root.dialStyle !== "none"

        // Dots
        Repeater {
            model: root.dialStyle === "dots" ? 12 : 0
            Item {
                required property int index
                anchors.fill: parent
                rotation: 360 / 12 * index
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    width: 10
                    height: 10
                    radius: 5
                    color: root.colOnBackground
                }
            }
        }

        // Full hour + minute ticks
        Repeater {
            model: root.dialStyle === "full" ? 12 : 0
            Item {
                required property int index
                anchors.fill: parent
                rotation: 360 / 12 * index
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8
                    width: 16
                    height: 3.5
                    radius: 2
                    color: root.colOnBackground
                }
            }
        }
        Repeater {
            model: root.dialStyle === "full" ? 60 : 0
            Item {
                required property int index
                anchors.fill: parent
                rotation: 360 / 60 * index
                // Skip positions that already have hour ticks
                visible: index % 5 !== 0
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    width: 6
                    height: 1.5
                    radius: 1
                    color: root.colOnBackground
                    opacity: 0.7
                }
            }
        }

        // 3-6-9-12 numbers
        Repeater {
            model: root.dialStyle === "numbers" ? 4 : 0
            Item {
                id: numItem
                required property int index
                anchors.fill: parent
                rotation: 360 / 4 * (index + 1)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    rotation: -numItem.rotation
                    text: 12 / 4 * (numItem.index + 1)
                    color: root.colOnBackground
                    font.pixelSize: 28
                    font.weight: Font.Black
                    font.family: "Inter"
                }
            }
        }
    }

    // Optional inner hour-mark ring
    Item {
        id: hourMarksRing
        anchors.centerIn: parent
        width: 135
        height: 135
        visible: root.hourMarks
        opacity: root.hourMarks ? 1 : 0
        z: 1

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.colOnBackground

            Repeater {
                model: 12
                Item {
                    required property int index
                    anchors.fill: parent
                    rotation: 360 / 12 * index
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 8
                        width: 12
                        height: 4
                        radius: 2
                        color: root.mix(root.colBackgroundInfo, root.colOnBackground, 0.5)
                    }
                }
            }
        }
    }

    // Digital time column in the middle (end-4 timeIndicators)
    Column {
        id: timeColumn
        anchors.centerIn: parent
        spacing: root.hourMarks ? -10 : -14
        visible: root.timeIndicators
        z: 2
        opacity: root.timeIndicators ? 1 : 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hoursText
            color: root.colBackgroundInfo
            font.pixelSize: root.hourMarks ? 36 : 56
            font.weight: Font.Bold
            font.family: "Inter"
            Behavior on font.pixelSize {
                NumberAnimation {
                    duration: 250 * Config.animationSpeed
                    easing.type: Easing.OutCubic
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.minutesText
            color: root.colBackgroundInfo
            font.pixelSize: root.hourMarks ? 36 : 56
            font.weight: Font.Bold
            font.family: "Inter"
            Behavior on font.pixelSize {
                NumberAnimation {
                    duration: 250 * Config.animationSpeed
                    easing.type: Easing.OutCubic
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.amPmText !== ""
            text: root.amPmText
            color: root.colBackgroundInfo
            font.pixelSize: root.hourMarks ? 16 : 20
            font.weight: Font.Bold
            font.family: "Inter"
        }
    }

    // Minute hand
    Item {
        id: minuteHand
        anchors.fill: parent
        visible: root.minuteHandStyle !== "hide"
        z: 3
        rotation: -90 + (360 / 60) * root.clockMinute
        transformOrigin: Item.Center

        Behavior on rotation {
            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: 300 * Config.animationSpeed
                easing.type: Easing.OutCubic
            }
        }

        readonly property real handWidth: root.minuteHandStyle === "bold" ? 18
            : root.minuteHandStyle === "medium" ? 12
            : root.minuteHandStyle === "thin" ? 5
            : 8
        readonly property real handLength: root.implicitSize * 0.38

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width / 2 - minuteHand.handWidth / 2 - (root.minuteHandStyle === "classic" ? 12 : 0)
            width: minuteHand.handLength
            height: minuteHand.handWidth
            radius: root.minuteHandStyle === "classic" ? 2 : height / 2
            color: root.colMinuteHand
            Behavior on height {
                NumberAnimation {
                    duration: 200 * Config.animationSpeed
                }
            }
            Behavior on color {
                EffectBehavior {}
            }
        }
    }

    // Hour hand
    Item {
        id: hourHand
        anchors.fill: parent
        visible: root.hourHandStyle !== "hide"
        z: root.hourHandStyle === "hollow" ? 2 : 4
        rotation: -90 + (360 / 12) * (root.clockHour + root.clockMinute / 60)
        transformOrigin: Item.Center

        Behavior on rotation {
            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: 350 * Config.animationSpeed
                easing.type: Easing.OutCubic
            }
        }

        readonly property real handWidth: 18
        readonly property real handLength: root.implicitSize * 0.28
        readonly property real fillAlpha: root.hourHandStyle === "hollow" ? 0 : 1

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width / 2 - hourHand.handWidth / 2 - (root.hourHandStyle === "classic" ? 12 : 0)
            width: hourHand.handLength
            height: root.hourHandStyle === "classic" ? 8 : hourHand.handWidth
            radius: root.hourHandStyle === "classic" ? 2 : height / 2
            color: Qt.rgba(root.colHourHand.r, root.colHourHand.g, root.colHourHand.b, hourHand.fillAlpha)
            border.color: root.colHourHand
            border.width: root.hourHandStyle === "hollow" || root.hourHandStyle === "fill" ? 3.5 : 0
            Behavior on color {
                EffectBehavior {}
            }
        }
    }

    // Second hand / dot
    Item {
        id: secondHand
        anchors.fill: parent
        visible: root.secondHandStyle !== "hide"
        z: root.secondHandStyle === "line" ? 4 : 5
        // End-4: rotation = (360/60 * sec) + 90 with left-anchored hand
        rotation: (360 / 60) * root.clockSecond + 90
        transformOrigin: Item.Center

        Behavior on rotation {
            // Animating every second is expensive; only when continuously rotating face
            enabled: root.constantlyRotate
            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: 1000
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: root.secondHandStyle === "dot" ? 18 : 12
            width: root.secondHandStyle === "dot" ? 16 : root.implicitSize * 0.38
            height: root.secondHandStyle === "dot" ? 16 : 2.5
            radius: Math.min(width, height) / 2
            color: root.colSecondHand
            Behavior on color {
                EffectBehavior {}
            }
        }

        // Classic mid-hand bob
        Rectangle {
            visible: root.secondHandStyle === "classic"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 40
            width: 12
            height: 12
            radius: 3
            color: root.colSecondHand
        }
    }

    // Center cap
    Rectangle {
        z: 6
        anchors.centerIn: parent
        visible: root.minuteHandStyle !== "bold"
        width: 8
        height: 8
        radius: 4
        color: root.minuteHandStyle === "medium" ? root.colBackground : root.colMinuteHand
        Behavior on color {
            EffectBehavior {}
        }
    }

    // Date — bubble style (day top-left, month bottom-right)
    Item {
        anchors.fill: parent
        z: 7
        visible: root.dateStyle === "bubble"

        // Day bubble
        Item {
            width: 52
            height: 52
            x: root.implicitSize * 0.12
            y: root.implicitSize * 0.12

            Rectangle {
                anchors.fill: parent
                radius: width * 0.35
                color: Colors.tertiaryContainer
                // Soft pentagon-ish feel via rotation
                rotation: -18
            }
            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(root.currentTime, "d")
                color: Colors.onTertiaryContainer
                font.pixelSize: 22
                font.weight: Font.Black
                font.family: "Inter"
                rotation: 0
            }
        }

        // Month bubble
        Item {
            width: 52
            height: 52
            x: root.implicitSize * 0.66
            y: root.implicitSize * 0.66

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Colors.secondaryContainer
            }
            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(root.currentTime, "MM")
                color: Colors.onSecondaryContainer
                font.pixelSize: 20
                font.weight: Font.Black
                font.family: "Inter"
            }
        }
    }

    // Date — rect style (day number on the right)
    Rectangle {
        z: 7
        visible: root.dateStyle === "rect"
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 18
        width: 40
        height: 28
        radius: 6
        color: root.mix(root.colBackgroundInfo, Colors.secondaryContainer, 0.5)

        Text {
            anchors.centerIn: parent
            text: Qt.formatDate(root.currentTime, "dd")
            color: Colors.onSecondary
            font.pixelSize: 16
            font.weight: Font.Black
            font.family: "Inter"
        }
    }

    // Date — border style (letters around the rim)
    Item {
        id: borderDate
        anchors.fill: parent
        z: 7
        visible: root.dateStyle === "border"

        readonly property string dateText: Qt.formatDate(root.currentTime, "ddd dd")
        readonly property real angleStep: 12 * Math.PI / 180
        readonly property real radius: root.implicitSize * 0.39

        Repeater {
            model: borderDate.dateText.length
            Text {
                required property int index
                readonly property real angle: index * borderDate.angleStep - Math.PI / 2
                    - (borderDate.angleStep * (borderDate.dateText.length - 1)) / 2
                x: root.width / 2 + borderDate.radius * Math.cos(angle) - width / 2
                y: root.height / 2 + borderDate.radius * Math.sin(angle) - height / 2
                rotation: angle * 180 / Math.PI + 90
                text: borderDate.dateText.charAt(index)
                color: root.colOnBackground
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.family: "Inter"
            }
        }
    }
}
