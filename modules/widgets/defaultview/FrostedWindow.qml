import QtQuick

// A cheap "window" into an already-blurred background item.
//
// Multiple FrostedWindows can share ONE blurSource — the Gaussian blur
// itself is only ever computed once, by whoever owns blurSource. Each
// FrostedWindow just crops the exact slice of that already-blurred
// texture that sits behind it (a plain texture sample, not a re-blur),
// so every widget's glass stays perfectly continuous with its
// neighbours and with the outer rim blur — no seams, no "misplaced"
// crops, no fake alpha-only tinting.
//
// Usage (inside a pill that sits on top of `mainBgBlurred`, which is
// anchored 1:1 to `outerFramedCard`):
//
//   FrostedWindow {
//       anchors.fill: parent
//       z: -1                       // stay behind this pill's own tint/content
//       blurSource: mainBgBlurred
//       mapTarget: outerFramedCard
//   }
//
Item {
    id: root

    // The single shared MultiEffect-blurred item (e.g. mainBgBlurred).
    required property Item blurSource

    // The item whose local (0,0) == blurSource's local (0,0).
    // i.e. whatever blurSource is itself anchored to, unshifted.
    required property Item mapTarget

    // Soft highlight along the top edge, like light catching real glass.
    // On by default since every pill wants it; set false to opt out.
    property bool showSheen: true

    // Flat dark wash under the sheen, applied uniformly regardless of
    // album art. Text and icon colours are only ever contrast-checked
    // against a fixed theme, not against whatever's actually playing -
    // pale/high-key artwork (like a white album cover) can otherwise
    // wash controls out completely. This guarantees a floor of
    // contrast no matter what's behind it. 0 disables it.
    property real scrimOpacity: 0.35

    // mapToItem() is a plain method call, not a bound property — QML's
    // binding engine can't see inside a `transform:` list (e.g. a
    // parallax Translate), so a simple `property point _origin:
    // mapToItem(...)` binding only ever evaluates once and then goes
    // stale. That staleness is exactly what reads as "a static copy of
    // the background": the blur itself keeps updating live, but the
    // window cropped into it stops moving. FrameAnimation forces a
    // fresh lookup every rendered frame instead, so this tracks any
    // transform — parallax or otherwise — with zero lag.
    property point _origin: Qt.point(0, 0)

    FrameAnimation {
        running: true
        onTriggered: {
            let pt = root.mapToItem(root.mapTarget, 0, 0);
            let tx = 0, ty = 0;
            let p = root;
            while (p && p !== root.mapTarget) {
                if (p.transform) {
                    for (let i = 0; i < p.transform.length; i++) {
                        let t = p.transform[i];
                        if (t.x !== undefined) tx += t.x;
                        if (t.y !== undefined) ty += t.y;
                    }
                }
                p = p.parent;
            }
            if (root.blurSource && root.blurSource.transform) {
                for (let i = 0; i < root.blurSource.transform.length; i++) {
                    let t = root.blurSource.transform[i];
                    if (t.x !== undefined) tx -= t.x;
                    if (t.y !== undefined) ty -= t.y;
                }
            }
            root._origin = Qt.point(pt.x + tx, pt.y + ty);
        }
    }

    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: root.blurSource
        live: true
        hideSource: false // blurSource must stay visible for the rim/gaps too
        sourceRect: Qt.rect(root._origin.x, root._origin.y, root.width, root.height)
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.scrimOpacity
    }

    Rectangle {
        visible: root.showSheen
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.55
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.09) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }
}
