import QtQuick
import "../.."

Rectangle {
    id: root

    property real topLeftR: 28
    property real topRightR: 28
    property real bottomLeftR: 28
    property real bottomRightR: 28

    property bool morphOnHover: false
    property real hoverRadius: 40

    property color tone: Colors.surfaceContainer
    property color outlineTone: Qt.alpha(Colors.outlineVariant, 0.35)
    property real outlineWidth: 1

    color: tone
    border.color: outlineTone
    border.width: outlineWidth
    antialiasing: true

    topLeftRadius: morphOnHover && hoverHandler.hovered ? hoverRadius : topLeftR
    topRightRadius: morphOnHover && hoverHandler.hovered ? hoverRadius : topRightR
    bottomLeftRadius: morphOnHover && hoverHandler.hovered ? hoverRadius : bottomLeftR
    bottomRightRadius: morphOnHover && hoverHandler.hovered ? hoverRadius : bottomRightR

    Behavior on topLeftRadius { SpringBehavior {} }
    Behavior on topRightRadius { SpringBehavior {} }
    Behavior on bottomLeftRadius { SpringBehavior {} }
    Behavior on bottomRightRadius { SpringBehavior {} }
    Behavior on color { EffectBehavior {} }
    Behavior on border.color { EffectBehavior {} }

    HoverHandler {
        id: hoverHandler
        enabled: root.morphOnHover
    }
}
