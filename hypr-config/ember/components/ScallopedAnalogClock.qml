import QtQuick
import ".."
import "common"

Item {
    id: root

    property date currentTime: new Date()
    implicitWidth: 280
    implicitHeight: 280

    property real secondAngle: currentTime.getSeconds() * 6
    property real minuteAngle: (currentTime.getMinutes() + currentTime.getSeconds() / 60) * 6
    property real hourAngle: ((currentTime.getHours() % 12) + currentTime.getMinutes() / 60) * 30

    property vector2d blurVelocity: Qt.vector2d(0, 0)

    property int _prevSec: -1
    onCurrentTimeChanged: {
        var s = currentTime.getSeconds()
        if (s !== _prevSec) {
            var rad = (secondAngle - 90) * Math.PI / 180
            blurVelocity = Qt.vector2d(0.12 * Math.cos(rad), 0.12 * Math.sin(rad))
            _prevSec = s
        }
    }

    Behavior on secondAngle {
        RotationAnimation {
            duration: 300 * Config.animationSpeed
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
            direction: RotationAnimation.Shortest
        }
    }

    Behavior on minuteAngle {
        RotationAnimation {
            duration: 350 * Config.animationSpeed
            easing.type: Easing.OutQuint
            direction: RotationAnimation.Shortest
        }
    }

    Behavior on hourAngle {
        RotationAnimation {
            duration: 400 * Config.animationSpeed
            easing.type: Easing.OutQuint
            direction: RotationAnimation.Shortest
        }
    }

    // --- Scalloped Flower Face ---
    Canvas {
        id: faceCanvas
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded

        readonly property real rBase: (Math.min(width, height) - 12) / 2
        readonly property int lobes: 12
        readonly property real rOuter: rBase
        readonly property real rInner: rBase * 0.88

        property color fillColor: Colors.surfaceContainer
        property color accentColor: Colors.primary

        onFillColorChanged: requestPaint()
        onAccentColorChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2
            var cy = height / 2
            var R = rOuter
            var r = rInner
            var n = lobes

            ctx.beginPath()

            for (var i = 0; i < n; i++) {
                var a0 = (i * 2 * Math.PI) / n
                var a1 = a0 + Math.PI / n
                var a2 = a0 + 2 * Math.PI / n

                var px = cx + R * Math.cos(a0)
                var py = cy + R * Math.sin(a0)
                var vx = cx + r * Math.cos(a1)
                var vy = cy + r * Math.sin(a1)
                var nx = cx + R * Math.cos(a2)
                var ny = cy + R * Math.sin(a2)

                var dist = Math.sqrt((px - vx) * (px - vx) + (py - vy) * (py - vy))
                var cp = dist * 0.45

                var txP = -Math.sin(a0)
                var tyP = Math.cos(a0)
                var txV1 = -Math.sin(a1)
                var tyV1 = Math.cos(a1)
                var txV2 = -Math.sin(a1)
                var tyV2 = Math.cos(a1)
                var txN = -Math.sin(a2)
                var tyN = Math.cos(a2)

                if (i === 0) {
                    ctx.moveTo(px, py)
                }

                ctx.bezierCurveTo(
                    px + txP * cp, py + tyP * cp,
                    vx - txV1 * cp, vy - tyV1 * cp,
                    vx, vy
                )
                ctx.bezierCurveTo(
                    vx + txV2 * cp, vy + tyV2 * cp,
                    nx - txN * cp, ny - tyN * cp,
                    nx, ny
                )
            }

            ctx.closePath()

            var grad = ctx.createRadialGradient(cx, cy, r * 0.3, cx, cy, R * 1.05)
            grad.addColorStop(0.0, Qt.lighter(fillColor, 1.06))
            grad.addColorStop(1.0, fillColor)
            ctx.fillStyle = grad
            ctx.fill()

            ctx.strokeStyle = Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
            ctx.lineWidth = 1.5
            ctx.stroke()
        }
    }

    // --- Hour Hand ---
    Rectangle {
        id: hourHand
        width: 22
        height: faceCanvas.rBase * 0.55
        radius: width / 2
        color: Colors.primary
        transformOrigin: Item.Bottom
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.verticalCenter
        }
        rotation: root.hourAngle

        Behavior on rotation {
            RotationAnimation {
                duration: 400 * Config.animationSpeed
                easing.type: Easing.OutQuint
                direction: RotationAnimation.Shortest
            }
        }
        Behavior on color { EffectBehavior {} }
    }

    // --- Minute Hand ---
    Rectangle {
        id: minuteHand
        width: 14
        height: faceCanvas.rBase * 0.78
        radius: width / 2
        color: Colors.secondary
        transformOrigin: Item.Bottom
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.verticalCenter
        }
        rotation: root.minuteAngle

        Behavior on rotation {
            RotationAnimation {
                duration: 350 * Config.animationSpeed
                easing.type: Easing.OutQuint
                direction: RotationAnimation.Shortest
            }
        }
        Behavior on color { EffectBehavior {} }
    }

    // --- Seconds Dot (tracks a circular path near the scallop edge) ---
    Rectangle {
        id: secondDot
        width: 8
        height: 8
        radius: width / 2
        color: Colors.tertiary

        readonly property real rad: (root.secondAngle - 90) * Math.PI / 180
        readonly property real orbitR: faceCanvas.rBase * 0.78

        x: parent.width / 2 + orbitR * Math.cos(rad) - width / 2
        y: parent.height / 2 + orbitR * Math.sin(rad) - height / 2

        Behavior on x { SpringBehavior { duration: 250 * Config.animationSpeed } }
        Behavior on y { SpringBehavior { duration: 250 * Config.animationSpeed } }
        Behavior on color { EffectBehavior {} }
    }

    // --- Center Cap ---
    Rectangle {
        width: 18
        height: width
        radius: width / 2
        color: Colors.surfaceContainer
        border.color: Qt.alpha(Colors.outlineVariant, 0.25)
        border.width: 1
        anchors.centerIn: parent
        z: 1

        Rectangle {
            width: 8
            height: width
            radius: width / 2
            color: Colors.primary
            anchors.centerIn: parent
        }
    }
}
