import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.config
import qs.modules.theme
import qs.modules.services

Item {
    id: root

    property string fallbackText: ""
    property bool compactMode: true
    property color textColor: Colors.overBackground
    property color activeLineColor: Colors.primary

    readonly property bool hasSynced: LyricsService.hasSyncedLyrics
    readonly property bool hasPlain: LyricsService.hasPlainLyrics
    readonly property bool hasLyrics: LyricsService.hasLyrics
    readonly property int currentIndex: LyricsService.currentIndex
    readonly property bool isPlaying: LyricsService.isPlaying
    readonly property bool isIntro: LyricsService.isIntro

    readonly property string currentLineText: {
        if (!hasLyrics) return root.fallbackText;
        if (hasSynced) {
            if (currentIndex >= 0 && currentIndex < LyricsService.syncedLines.length) {
                return LyricsService.syncedLines[currentIndex].text || "";
            }
            if (isIntro) return "♪ ~ ♪";
            return "";
        }
        // Plain-only lyrics: show fallback (Artist - Title) in compact mode
        return root.fallbackText;
    }

    readonly property bool hasActivePlayer: LyricsService.activePlayer !== null

    // State opacity: gentle dim when paused (only if an active media player exists)
    property real playbackOpacity: (hasActivePlayer && !root.isPlaying) ? 0.25 : 1.0
    Behavior on playbackOpacity {
        enabled: Config.animDuration > 0
        NumberAnimation { duration: 500; easing.type: Easing.InOutSine }
    }

    // =========================================
    // COMPACT NOTCH VIEW (Single-line cross-fade)
    // =========================================
    Item {
        id: compactNotchView
        anchors.fill: parent
        visible: root.compactMode
        opacity: root.playbackOpacity

        // Fallback / Intro text (when no synced line is active)
        Text {
            id: compactFallbackLabel
            anchors.centerIn: parent
            width: parent.width - 8
            text: root.hasSynced ? (root.isIntro ? "♪ ~ ♪" : root.currentLineText) : root.fallbackText
            textFormat: Text.PlainText
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.bold: true
            color: root.textColor
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: !root.hasSynced || root.currentIndex < 0
            opacity: visible ? 1.0 : 0.0

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: 350; easing.type: Easing.InOutSine }
            }
        }

        // Active synced lyric — single-line cross-fade
        Item {
            anchors.fill: parent
            visible: root.hasSynced && root.currentIndex >= 0

        // Soft glow behind active text
            MultiEffect {
                anchors.fill: activeNotchTextContainer
                source: activeNotchTextContainer
                shadowEnabled: true
                shadowColor: root.activeLineColor
                shadowBlur: 0.7
                shadowOpacity: 0.5
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }

            Item {
                id: activeNotchTextContainer
                anchors.fill: parent
                clip: true

                Text {
                    id: activeNotchText
                    anchors.centerIn: parent
                    width: parent.width - 8
                    text: root.currentLineText
                    textFormat: Text.PlainText
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: root.activeLineColor
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap

                    // Cross-fade + gentle 4px vertical slide on line change
                    property string lastText: ""
                    onTextChanged: {
                        if (text !== lastText && text !== "") {
                            lineTransitionAnim.restart();
                            lastText = text;
                        }
                    }

                    SequentialAnimation {
                        id: lineTransitionAnim
                        running: false
                        ParallelAnimation {
                            NumberAnimation { target: activeNotchText; property: "opacity"; from: 0.2; to: 1.0; duration: 400; easing.type: Easing.InOutSine }
                            NumberAnimation { target: activeNotchText; property: "anchors.verticalCenterOffset"; from: 4; to: 0; duration: 400; easing.type: Easing.InOutQuad }
                        }
                    }
                }

             
            }
        }
    }

    // =========================================
    // DASHBOARD FULL PLAYER VIEW (3-Line Karaoke)
    // =========================================
    Item {
        id: fullDashboardView
        anchors.fill: parent
        visible: !root.compactMode
        opacity: root.playbackOpacity

        // Fallback when no lyrics
        Text {
            anchors.centerIn: parent
            width: parent.width
            text: root.fallbackText
            textFormat: Text.PlainText
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize + 2
            font.bold: true
            color: root.textColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: !root.hasLyrics
        }

        // Soft radial ambient glow behind lyrics
        Image {
            anchors.centerIn: parent
            width: parent.width * 1.4
            height: parent.height * 1.4
            z: -1
            opacity: root.hasLyrics && root.isPlaying ? 0.35 : 0.15
            visible: root.hasLyrics

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation { duration: 600; easing.type: Easing.InOutSine }
            }

            source: {
                const color = root.activeLineColor.toString();
                const svgString = `<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">
                    <defs>
                        <radialGradient id="g" cx="50%" cy="50%" r="50%">
                            <stop offset="0%" stop-color="${color}" stop-opacity="0.6"/>
                            <stop offset="40%" stop-color="${color}" stop-opacity="0.25"/>
                            <stop offset="100%" stop-color="${color}" stop-opacity="0"/>
                        </radialGradient>
                    </defs>
                    <circle cx="100" cy="100" r="100" fill="url(#g)"/>
                </svg>`;
                return "data:image/svg+xml;utf8," + encodeURIComponent(svgString);
            }
            sourceSize: Qt.size(200, 200)
            smooth: true
            asynchronous: true
        }

        // Synced 3-line karaoke
        ListView {
            id: fullSyncedListView
            anchors.fill: parent
            visible: root.hasSynced
            model: LyricsService.syncedLines
            currentIndex: root.currentIndex >= 0 ? root.currentIndex : 0
            preferredHighlightBegin: parent.height / 2 - 14
            preferredHighlightEnd: parent.height / 2 + 14
            highlightRangeMode: ListView.ApplyRange
            highlightMoveDuration: Config.animDuration > 0 ? 750 : 300
            clip: true
            interactive: false

            delegate: Item {
                id: fullDelegateRoot
                width: ListView.view.width
                height: fullLineText.implicitHeight + 4

                readonly property bool isCurrent: index === root.currentIndex

                // Soft text glow for active line
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    text: modelData.text || ""
                    textFormat: Text.PlainText
                    font: fullLineText.font
                    color: root.activeLineColor
                    opacity: fullDelegateRoot.isCurrent ? 0.75 : 0.0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: fullDelegateRoot.isCurrent

                    layer.enabled: fullDelegateRoot.isCurrent
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 20
                        blur: 0.8
                    }

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: 300; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    id: fullLineText
                    anchors.centerIn: parent
                    width: parent.width - 16
                    text: modelData.text || ""
                    textFormat: Text.PlainText
                    font.family: Config.theme.font
                    font.pixelSize: fullDelegateRoot.isCurrent ? Config.theme.fontSize : Math.max(9, Config.theme.fontSize - 1)
                    font.bold: fullDelegateRoot.isCurrent
                    color: fullDelegateRoot.isCurrent ? root.activeLineColor : root.textColor
                    opacity: fullDelegateRoot.isCurrent ? 1.0 : (Math.abs(index - root.currentIndex) === 1 ? 0.45 : 0.2)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight

                    Behavior on font.pixelSize {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: 400; easing.type: Easing.InOutSine }
                    }
                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: 400; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        // Plain unsynced lyrics scroll
        Flickable {
            anchors.fill: parent
            visible: !root.hasSynced && root.hasPlain
            contentWidth: width
            contentHeight: fullPlainText.implicitHeight
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: fullPlainText
                width: parent.width
                text: LyricsService.plainLyrics
                textFormat: Text.PlainText
                font.family: Config.theme.font
                font.pixelSize: Math.max(10, Config.theme.fontSize)
                color: root.textColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
