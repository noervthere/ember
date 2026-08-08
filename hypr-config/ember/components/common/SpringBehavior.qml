import QtQuick
import "../.."

NumberAnimation {
    duration: 500 * Config.animationSpeed
    easing.type: Easing.OutBack
    easing.overshoot: 1.0
}
