import QtQuick
import "../.."

Item {
    id: root

    property string digit: "0"
    property color textColor: Colors.onSurface
    property font font
    property real animationSpeed: Config.animationSpeed

    readonly property int value: (digit >= "0" && digit <= "9") ? parseInt(digit) : -1
    readonly property bool active: value !== -1

    width: active ? activeText.implicitWidth : 0
    opacity: active ? 1.0 : 0.0
    implicitWidth: activeText.implicitWidth
    implicitHeight: dummyText.implicitHeight
    clip: true

    Behavior on width {
        NumberAnimation {
            duration: 350 * root.animationSpeed
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        ColorAnimation {
            duration: 250 * root.animationSpeed
        }
    }

    Text {
        id: dummyText
        text: "0"
        font: root.font
        visible: false
    }

    Text {
        id: activeText
        text: root.digit
        font: root.font
        visible: false
    }

    Column {
        id: column
        width: parent.width
        y: active ? -root.value * dummyText.implicitHeight : 0

        Behavior on y {
            NumberAnimation {
                duration: 450 * root.animationSpeed
                easing.type: Easing.OutBack
                easing.overshoot: 1.05
            }
        }

        Repeater {
            model: 10
            Text {
                text: index.toString()
                font: root.font
                color: root.textColor
                width: parent.width
                height: dummyText.implicitHeight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
