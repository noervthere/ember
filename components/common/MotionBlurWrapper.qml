import QtQuick
import "../.."

// Wraps any child item with velocity-tracked directional motion blur.
//
// Place any widget inside this component. On every frame tick it measures
// the item's (x, y) delta and/or an explicit velocity hint from the wrapped
// content, then feeds the result to MotionBlur.frag as uVelocity.
//
// Properties the caller can override:
//   blurSamples  -- tap count passed to the shader (default 11, max 31).
//   blurStrength -- [0,1] master attenuation (default 0.6).
//   velocityHint -- synthetic velocity (normalised texture-space) injected
//                   by the wrapped clock face when internal motion occurs
//                   (hand rotation, digit ticks, etc.).
//
// Internal motion tracking:
//   Each clock face exposes a blurVelocity property.  When set to a non-zero
//   vector the wrapper injects it as a one-shot velocity pulse, giving a
//   visible directional blur trail that decays naturally.

Item {
    id: root

    property int   blurSamples:  11
    property real  blurStrength: 0.6
    property var   velocityHint: Qt.vector2d(0, 0)

    implicitWidth:  shaderEffect.implicitWidth
    implicitHeight: shaderEffect.implicitHeight

    // --- velocity tracking ---

    property real _prevX: 0
    property real _prevY: 0
    property real _vx:    0
    property real _vy:    0

    onXChanged: _dirty = true
    onYChanged: _dirty = true
    onVelocityHintChanged: _dirty = true

    property bool _dirty: false

    FrameAnimation {
        id: frameLoop
        running: true
        onTriggered: {
            if (root._dirty) {
                var px = (root.x - root._prevX) / Math.max(root.width,  1)
                var py = (root.y - root._prevY) / Math.max(root.height, 1)
                root._prevX = root.x
                root._prevY = root.y

                // Take whichever velocity source has the larger magnitude
                var hx = root.velocityHint.x
                var hy = root.velocityHint.y
                if (hx * hx + hy * hy > px * px + py * py) {
                    root._vx = hx
                    root._vy = hy
                } else {
                    root._vx = px
                    root._vy = py
                }
                root._dirty = false
            } else {
                root._vx *= 0.6
                root._vy *= 0.6
            }
        }
    }

    // --- render pipeline ---

    ShaderEffectSource {
        id: src
        sourceItem: contentItem
        hideSource:  true
        anchors.fill: parent
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }

    ShaderEffect {
        id: shaderEffect
        anchors.fill: parent

        property var   source:    src
        property var   uVelocity: Qt.vector2d(root._vx, root._vy)
        property real  uStrength: root.blurStrength * Config.animationSpeed
        property int   uSamples:  root.blurSamples

        fragmentShader: Qt.resolvedUrl("../../shaders/MotionBlur.frag.qsb")
        blending: true
    }

    // Expose contentItem as the default property so children declared inside
    // MotionBlurWrapper end up inside contentItem, not the root Item.
    default property alias content: contentItem.data
}
