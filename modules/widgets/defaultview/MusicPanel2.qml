import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

Item {
    id: panel
    anchors.fill: parent
    clip: true

    required property var player
    property bool panelVisible: false
    property bool isBottom: false // Passed from DefaultView

    // --- Player state bindings ---
    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing
    readonly property real position: player?.position ?? 0.0
    readonly property real length: player?.length ?? 1.0
    readonly property bool hasArtwork: (player?.trackArtUrl ?? "") !== ""
    readonly property string trackTitle: player?.trackTitle ?? ""
    readonly property string trackArtist: player?.trackArtist ?? ""
    readonly property string trackAlbum: player?.trackAlbum ?? ""

    // --- Layout constants ---
    readonly property int discSize: 156
    readonly property int targetLayoutHeight: 246 // 270 - 12 (top) - 12 (bottom)

    // --- Position tracking ---
    Timer {
        running: panel.isPlaying && panel.panelVisible
        interval: 1000
        repeat: true
        onTriggered: {
            if (!seekSlider.isDragging) {
                seekSlider.value = panel.length > 0 ? Math.min(1.0, panel.position / panel.length) : 0;
            }
            panel.player?.positionChanged();
        }
    }

    Connections {
        target: panel.player
        function onPositionChanged() {
            if (!seekSlider.isDragging && panel.player) {
                seekSlider.value = panel.length > 0 ? Math.min(1.0, panel.position / panel.length) : 0;
            }
        }
    }

    function formatTime(seconds) {
        const totalSeconds = Math.floor(seconds);
        const minutes = Math.floor(totalSeconds / 60);
        const secs = totalSeconds % 60;
        return minutes + ":" + (secs < 10 ? "0" : "") + secs;
    }

    // =========================================================================
    // PARALLAX MOUSE TRACKING
    // =========================================================================
    property real _mouseNormX: 0  // -1 to 1
    property real _mouseNormY: 0  // -1 to 1
    property bool _mouseInside: false

    Behavior on _mouseNormX {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }
    Behavior on _mouseNormY {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    MouseArea {
        id: parallaxArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton  // pass clicks through
        onPositionChanged: mouse => {
            panel._mouseNormX = (mouse.x / width) * 2 - 1;
            panel._mouseNormY = (mouse.y / height) * 2 - 1;
        }
        onEntered: panel._mouseInside = true
        onExited: {
            panel._mouseInside = false;
            panel._mouseNormX = 0;
            panel._mouseNormY = 0;
        }
    }

    // --- Cursor glow (Ultra-efficient SVG Flashlight) ---
    Image {
        id: cursorGlow
        width: 320
        height: 320
        x: parallaxArea.mouseX - width / 2
        y: parallaxArea.mouseY - height / 2
        z: -1
        opacity: panel._mouseInside && panel.panelVisible ? 1.0 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutQuart }
        }

        source: {
            const color = Colors.primary.toString();
            const svgString = `<svg xmlns="http://www.w3.org/2000/svg" width="320" height="320">
                <defs>
                    <radialGradient id="g" cx="50%" cy="50%" r="50%">
                        <stop offset="0%" stop-color="${color}" stop-opacity="0.28"/>
                        <stop offset="25%" stop-color="${color}" stop-opacity="0.12"/>
                        <stop offset="55%" stop-color="${color}" stop-opacity="0.04"/>
                        <stop offset="100%" stop-color="${color}" stop-opacity="0"/>
                    </radialGradient>
                </defs>
                <circle cx="160" cy="160" r="160" fill="url(#g)"/>
            </svg>`;
            return "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
        }
        
        sourceSize: Qt.size(320, 320)
        smooth: true
        asynchronous: true
    }



    // =========================================================================
    // OUTER FRAMED CARD WITH CONTINUOUS DUAL-LAYER ALBUM BACKGROUND
    // =========================================================================
    StyledRect {
        id: outerFramedCard
        variant: "pane"
        anchors.fill: parent
        anchors.margins: 8
        z: -5
        visible: panel.panelVisible
        enableBorder: true
        clip: true

        // 1. Crisp, unblurred, saturated scaled album cover (visible in gaps & rim)
        Image {
            id: mainBgCrisp
            anchors.fill: parent
            anchors.margins: -16
            source: panel.hasArtwork ? panel.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            visible: panel.hasArtwork
            asynchronous: true

            transform: Translate {
                x: panel._mouseNormX * -8
                y: panel._mouseNormY * -6
            }
        }

        // 2. Downsampled image source for smooth continuous blur
        Image {
            id: mainBgBlurredSource
            anchors.fill: parent
            anchors.margins: -16
            source: panel.hasArtwork ? panel.player.trackArtUrl : ""
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true

            transform: Translate {
                x: panel._mouseNormX * -8
                y: panel._mouseNormY * -6
            }
        }

        // 3. Continuous MultiEffect blur layer over album cover
        MultiEffect {
            id: mainBgBlurred
            anchors.fill: parent
            source: mainBgBlurredSource
            blurEnabled: true
            blurMax: 32
            blur: 1.0
            opacity: panel.hasArtwork ? 0.85 : 0.0
            visible: panel.hasArtwork
        }
    }

    // =========================================================================
    // MAIN LAYOUT
    // =========================================================================
    RowLayout {
        id: mainLayout
        // FIXED HEIGHT & ANCHORED TO REVEAL EDGE
        // This prevents the layout from sliding or compressing during expansion.
        anchors.top: panel.isBottom ? undefined : parent.top
        anchors.bottom: panel.isBottom ? parent.bottom : undefined
        anchors.left: parent.left
        anchors.right: parent.right
        
        height: panel.targetLayoutHeight
        
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        anchors.topMargin: panel.isBottom ? 0 : 12
        anchors.bottomMargin: panel.isBottom ? 12 : 0
        spacing: 16
        visible: opacity > 0
        opacity: panel.panelVisible ? 1.0 : 0.0

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
        }

        // =====================================================================
        // 1. DISC PILL (left)
        // =====================================================================
        StyledRect {
            id: discArea
            variant: "pane"
            backgroundOpacity: 0.45
            enableBorder: true
            radius: Styling.radius(4)
            Layout.preferredWidth: panel.discSize + 16
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            clip: true
            visible: panel.panelVisible

            // Parallax transform on disc area (stronger shift)
            transform: Translate {
                x: panel._mouseNormX * 6
                y: panel._mouseNormY * 4
            }

            // --- Soft radial glow behind disc (Ultra-efficient SVG) ---
            Image {
                anchors.centerIn: parent
                width: panel.discSize + 24
                height: width
                opacity: panel.isPlaying ? glowVal : 0.08
                visible: panel.panelVisible

                property real glowVal: 0.15
                SequentialAnimation on glowVal {
                    running: panel.panelVisible && panel.isPlaying
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.22; duration: 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.12; duration: 1400; easing.type: Easing.InOutSine }
                }

                source: {
                    const color = Colors.primary.toString();
                    const svgString = `<svg xmlns="http://www.w3.org/2000/svg" width="184" height="184">
                        <defs>
                            <radialGradient id="g" cx="50%" cy="50%" r="50%">
                                <stop offset="70%" stop-color="${color}" stop-opacity="0.9"/>
                                <stop offset="100%" stop-color="${color}" stop-opacity="0"/>
                            </radialGradient>
                        </defs>
                        <circle cx="92" cy="92" r="92" fill="url(#g)"/>
                    </svg>`;
                    return "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
                }
                
                sourceSize: Qt.size(184, 184)
                smooth: true
                asynchronous: true
            }

            // --- Socket cavity ---
            Rectangle {
                id: discSocket
                anchors.centerIn: parent
                width: panel.discSize + 6
                height: width
                radius: width / 2
                color: Qt.darker(Colors.surfaceContainer, 1.12)
            }

            // --- Spinning disc ---
            Item {
                id: discContainer
                anchors.centerIn: parent
                width: panel.discSize
                height: panel.discSize

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: discMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                Item {
                    id: discMask
                    width: panel.discSize
                    height: panel.discSize
                    visible: false
                    layer.enabled: true
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "black"
                    }
                }

                Image {
                    id: discArtImage
                    anchors.fill: parent
                    source: panel.hasArtwork ? panel.player.trackArtUrl : panel.wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== ""
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }

                Image {
                    anchors.fill: parent
                    source: "file:///home/ovt/Projects/ember/assets/sound/disc.png"
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.85
                    smooth: true
                    mipmap: true
                }

                RotationAnimation {
                    id: discRotationAnim
                    target: discContainer; property: "rotation"
                    from: discContainer.rotation; to: discContainer.rotation + 360
                    duration: 8000; loops: Animation.Infinite
                    running: panel.panelVisible && panel.isPlaying
                }

                Connections {
                    target: panel
                    function onIsPlayingChanged() {
                        if (!panel.isPlaying) {
                            let r = discContainer.rotation % 360;
                            discRotationAnim.stop();
                            discContainer.rotation = r;
                        }
                    }
                    function onPanelVisibleChanged() {
                        if (!panel.panelVisible) {
                            let r = discContainer.rotation % 360;
                            discRotationAnim.stop();
                            discContainer.rotation = r;
                        }
                    }
                }

                Connections {
                    target: panel.player
                    function onPlaybackStateChanged() {
                        if (!panel.isPlaying) {
                            let r = discContainer.rotation % 360;
                            discRotationAnim.stop();
                            discContainer.rotation = r;
                        }
                    }
                }
            }

            // --- Tonearm ---
            Item {
                id: tonearm
                anchors.top: parent.top
                anchors.topMargin: 2
                anchors.right: parent.right
                anchors.rightMargin: 12
                width: 38
                height: 70
                z: 10

                transform: Rotation {
                    origin.x: 30
                    origin.y: 8
                    angle: panel.isPlaying ? 24 : 0
                    Behavior on angle {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    }
                }

                Image {
                    anchors.fill: parent
                    source: "file:///home/ovt/Projects/ember/assets/sound/needle.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
            }
        }

        // =====================================================================
        // 2. MIDDLE SECTION (Track Info Pill Top + Controls Pill Bottom)
        // =====================================================================
        ColumnLayout {
            id: middleSectionContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // Parallax transform on info section (lighter shift)
            transform: Translate {
                x: panel._mouseNormX * 3
                y: panel._mouseNormY * 2
            }

            // TOP ROW: Track Info Pill + Pet Mascot Pill
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 74
                spacing: 6

                // PILL 2: Track Details Pill
                StyledRect {
                    id: trackDetailsPill
                    variant: "pane"
                    backgroundOpacity: 0.45
                    enableBorder: true
                    radius: Styling.radius(3)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 1

                        Text {
                            text: "NOW PLAYING"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 2
                            font.weight: Font.Medium
                            color: Colors.secondary
                            Layout.fillWidth: true
                        }

                        Text {
                            text: panel.trackTitle || "Unknown"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(2)
                            font.weight: Font.DemiBold
                            color: Colors.overSurface
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }

                        Text {
                            text: {
                                let parts = [];
                                if (panel.trackArtist) parts.push(panel.trackArtist);
                                if (panel.trackAlbum) parts.push(panel.trackAlbum);
                                return parts.join(" • ");
                            }
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overSurfaceVariant
                            opacity: 0.7
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }
                    }
                }

                // PILL 3: Pet Mascot Pill (Compact Square)
                StyledRect {
                    id: petPill
                    variant: "pane"
                    backgroundOpacity: 0.45
                    enableBorder: true
                    radius: Styling.radius(3)
                    Layout.preferredWidth: 74
                    Layout.preferredHeight: 74
                    Layout.alignment: Qt.AlignVCenter
                    clip: true

                    AnimatedImage {
                        source: "file:///home/ovt/Projects/ember/assets/ambxst/pet.gif"
                        playing: panel.panelVisible && panel.isPlaying
                        width: 52; height: 52
                        anchors.centerIn: parent
                    }
                }
            }

            // BOTTOM ROW: PILL 4 - Controls & Progress Pill
            StyledRect {
                id: controlsPill
                variant: "pane"
                backgroundOpacity: 0.45
                enableBorder: true
                radius: Styling.radius(3)
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    PositionSlider {
                        id: seekSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        player: panel.player
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: panel.formatTime(panel.position)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                            opacity: 0.5
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "-" + panel.formatTime(Math.max(0, panel.length - panel.position))
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                            opacity: 0.5
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 16

                        Text {
                            text: Icons.shuffle
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: shuffleHover.hovered ? Colors.primary : Colors.overSurface
                            opacity: MprisController.hasShuffle ? 1.0 : 0.4
                            Behavior on color { ColorAnimation { duration: 150 } }
                            HoverHandler { id: shuffleHover }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (MprisController.hasShuffle) {
                                        MprisController.setShuffle(false);
                                    } else {
                                        MprisController.setShuffle(true);
                                    }
                                }
                            }
                        }

                        Text {
                            text: Icons.previous
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: prevHover.hovered ? Colors.primary : Colors.overSurface
                            opacity: panel.player?.canGoPrevious ? 1.0 : 0.3
                            scale: 1.0
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            HoverHandler { id: prevHover }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    parent.scale = 1.2;
                                    prevScaleTimer.restart();
                                    panel.player?.previous();
                                }
                            }
                            Timer { id: prevScaleTimer; interval: 100; onTriggered: parent.scale = 1.0 }
                        }

                        StyledRect {
                            id: playPauseButton
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            variant: "primary"
                            radius: panel.isPlaying ? Styling.radius(0) : Styling.radius(10)
                            animateRadius: false

                            Behavior on radius {
                                enabled: Config.animDuration > 0
                                NumberAnimation { duration: 300; easing.type: Easing.OutBack }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: panel.isPlaying ? Icons.pause : Icons.play
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: playPauseButton.item
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.player?.togglePlaying()
                            }
                        }

                        Text {
                            text: Icons.next
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: nextHover.hovered ? Colors.primary : Colors.overSurface
                            opacity: panel.player?.canGoNext ? 1.0 : 0.3
                            scale: 1.0
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            HoverHandler { id: nextHover }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    parent.scale = 1.2;
                                    nextScaleTimer.restart();
                                    panel.player?.next();
                                }
                            }
                            Timer { id: nextScaleTimer; interval: 100; onTriggered: parent.scale = 1.0 }
                        }

                        Text {
                            text: {
                                if (MprisController.loopState === MprisLoopState.Track)
                                    return Icons.repeatOnce;
                                if (MprisController.loopState === MprisLoopState.Playlist)
                                    return Icons.repeat;
                                return Icons.repeat;
                            }
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: repeatHover.hovered ? Colors.primary : Colors.overSurface
                            opacity: MprisController.loopState !== MprisLoopState.None ? 1.0 : 0.4
                            Behavior on color { ColorAnimation { duration: 150 } }
                            HoverHandler { id: repeatHover }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (MprisController.loopState === MprisLoopState.None) {
                                        MprisController.setLoopState(MprisLoopState.Playlist);
                                    } else if (MprisController.loopState === MprisLoopState.Playlist) {
                                        MprisController.setLoopState(MprisLoopState.Track);
                                    } else {
                                        MprisController.setLoopState(MprisLoopState.None);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 3. PILL 5: LYRICS PILL (right side)
        // =====================================================================
        StyledRect {
            id: lyricsSection
            variant: "pane"
            backgroundOpacity: 0.45
            enableBorder: true
            radius: Styling.radius(4)
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            clip: true
            visible: panel.panelVisible

            LyricScroller {
                anchors.fill: parent
                anchors.margins: 6
                compactMode: false
                textColor: Colors.overSurfaceVariant
                activeLineColor: Colors.primary
                fallbackText: (panel.trackArtist ? panel.trackArtist + " - " : "") + panel.trackTitle
            }
        }
    }
}