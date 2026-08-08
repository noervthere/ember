pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
import qs.modules.services

Singleton {
    id: root

    property var syncedLines: []
    property string plainLyrics: ""
    property int currentIndex: -1
    property bool isLoading: false
    property string currentTrackId: ""
    property string fetchingTrackId: ""

    readonly property bool hasSyncedLyrics: syncedLines.length > 0
    readonly property bool hasPlainLyrics: plainLyrics.trim() !== ""
    readonly property bool hasLyrics: hasSyncedLyrics || hasPlainLyrics
    readonly property bool isIntro: hasSyncedLyrics && currentIndex === -1

    readonly property var activePlayer: MprisController.activePlayer
    readonly property bool isPlaying: MprisController.isPlaying

    // 250ms periodic position poll timer gated on playback state
    Timer {
        id: positionPollTimer
        interval: 250
        repeat: true
        running: root.isPlaying && root.hasSyncedLyrics
        onTriggered: {
            if (root.activePlayer) {
                root.activePlayer.positionChanged();
            }
            root.updateCurrentIndex();
        }
    }

    // Debounce timer for track changes
    Timer {
        id: fetchDebounceTimer
        interval: 300
        repeat: false
        onTriggered: root.fetchLyrics()
    }

    Connections {
        target: MprisController
        function onActivePlayerChanged() {
            root.checkTrackChange();
        }
    }

    Connections {
        target: root.activePlayer ? root.activePlayer : null
        function onTrackTitleChanged() { root.checkTrackChange(); }
        function onTrackArtistChanged() { root.checkTrackChange(); }
        function onPositionChanged() { root.updateCurrentIndex(); }
        function onPlaybackStateChanged() {
            if (root.activePlayer) root.updateCurrentIndex();
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => root.checkTrackChange());
    }

    function checkTrackChange() {
        if (!Config.lyrics || !Config.lyrics.enable) {
            root.resetState();
            return;
        }

        let player = root.activePlayer;
        if (!player) {
            root.resetState();
            return;
        }

        let title = (player.trackTitle || "").trim();
        let artist = (player.trackArtist || "").trim();
        if (title === "") {
            root.resetState();
            return;
        }

        let trackId = artist + " - " + title;
        if (trackId !== root.currentTrackId) {
            // Immediately clear old track's lyrics to prevent stuck old lyrics!
            root.currentTrackId = trackId;
            root.syncedLines = [];
            root.plainLyrics = "";
            root.currentIndex = -1;
            root.isLoading = true;
            fetchDebounceTimer.restart();
        }
    }

    function resetState() {
        root.currentTrackId = "";
        root.fetchingTrackId = "";
        root.syncedLines = [];
        root.plainLyrics = "";
        root.currentIndex = -1;
        root.isLoading = false;
    }

    function updateCurrentIndex() {
        if (!root.hasSyncedLyrics) {
            root.currentIndex = -1;
            return;
        }

        let pos = root.activePlayer ? (root.activePlayer.position || 0) : 0;
        let idx = -1;
        for (let i = 0; i < root.syncedLines.length; i++) {
            if (pos >= root.syncedLines[i].time) {
                idx = i;
            } else {
                break;
            }
        }
        root.currentIndex = idx;
    }

    function fetchLyrics() {
        let player = root.activePlayer;
        if (!player) {
            root.resetState();
            return;
        }

        let title = (player.trackTitle || "").trim();
        let artist = (player.trackArtist || "").trim();

        if (title === "") {
            root.resetState();
            return;
        }

        root.fetchingTrackId = root.currentTrackId;

        if (Config.lyrics && Config.lyrics.enableLrclib) {
            fetchLrclib(artist, title);
        } else if (Config.lyrics && Config.lyrics.enableGenius) {
            fetchGenius(artist, title);
        } else {
            root.resetState();
        }
    }

    function fetchLrclib(artist, title) {
        let url = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(artist) + "&track_name=" + encodeURIComponent(title);
        let userAgent = "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0";
        lrclibProcess.command = ["bash", "-c", "curl -s -L -A '" + userAgent + "' '" + url.replace(/'/g, "'\\''") + "'"];
        lrclibProcess.running = true;
    }

    Process {
        id: lrclibProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isLoading || root.fetchingTrackId !== root.currentTrackId) return;
                let textTrimmed = text ? text.trim() : "";
                if (textTrimmed === "" || textTrimmed.startsWith("<")) {
                    root.fallbackToGeniusOrEmpty();
                    return;
                }

                try {
                    let data = JSON.parse(textTrimmed);
                    if (data && data.syncedLyrics && data.syncedLyrics.trim() !== "") {
                        let parsed = root.parseLrc(data.syncedLyrics);
                        if (parsed.length > 0) {
                            root.syncedLines = parsed;
                            root.plainLyrics = "";
                            root.isLoading = false;
                            root.updateCurrentIndex();
                            return;
                        }
                    } else if (data && data.plainLyrics && data.plainLyrics.trim() !== "") {
                        root.plainLyrics = data.plainLyrics.trim();
                    }
                } catch (e) {
                    console.warn("LyricsService: Failed to parse LRCLIB response:", e);
                }

                root.fallbackToGeniusOrEmpty();
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 && root.isLoading && root.fetchingTrackId === root.currentTrackId) {
                root.fallbackToGeniusOrEmpty();
            }
        }
    }

    function fallbackToGeniusOrEmpty() {
        let player = root.activePlayer;
        let apiKey = Config.lyrics ? (Config.lyrics.geniusApiKey || "") : "";
        let enableGenius = Config.lyrics ? Config.lyrics.enableGenius : true;

        if (enableGenius && apiKey.trim() !== "" && player && root.fetchingTrackId === root.currentTrackId) {
            let title = (player.trackTitle || "").trim();
            let artist = (player.trackArtist || "").trim();
            fetchGenius(artist, title);
        } else {
            root.syncedLines = [];
            root.isLoading = false;
        }
    }

    function fetchGenius(artist, title) {
        let scriptPath = Quickshell.shellDir + "/scripts/lyrics/genius_lyrics.py";
        let apiKey = Config.lyrics ? (Config.lyrics.geniusApiKey || "") : "";
        geniusProcess.command = ["python3", scriptPath, artist, title, apiKey];
        geniusProcess.running = true;
    }

    Process {
        id: geniusProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.isLoading || root.fetchingTrackId !== root.currentTrackId) return;
                let textTrimmed = text ? text.trim() : "";
                try {
                    let data = JSON.parse(textTrimmed);
                    if (data && data.found && data.lyrics) {
                        root.syncedLines = [];
                        root.plainLyrics = data.lyrics.trim();
                        root.isLoading = false;
                        return;
                    }
                } catch (e) {
                    console.warn("LyricsService: Failed to parse Genius response:", e);
                }
                root.syncedLines = [];
                root.isLoading = false;
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 && root.isLoading && root.fetchingTrackId === root.currentTrackId) {
                root.syncedLines = [];
                root.isLoading = false;
            }
        }
    }

    function parseLrc(lrcText) {
        if (!lrcText) return [];
        let lines = lrcText.split("\n");
        let result = [];

        for (let i = 0; i < lines.length; i++) {
            let rawLine = lines[i].trim();
            if (!rawLine || rawLine.startsWith("[ar:") || rawLine.startsWith("[ti:") || rawLine.startsWith("[al:") || rawLine.startsWith("[by:") || rawLine.startsWith("[offset:")) continue;

            let timeRegex = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
            let match;
            let timestamps = [];

            while ((match = timeRegex.exec(rawLine)) !== null) {
                let mins = parseFloat(match[1]);
                let secs = parseFloat(match[2]);
                timestamps.push(mins * 60 + secs);
            }

            if (timestamps.length > 0) {
                let cleanText = rawLine.replace(/\[\d+:\d+(?:\.\d+)?\]/g, "").replace(/<[^>]+>/g, "").trim();
                if (cleanText.length > 0) {
                    for (let j = 0; j < timestamps.length; j++) {
                        result.push({ time: timestamps[j], text: cleanText });
                    }
                }
            }
        }
        result.sort((a, b) => a.time - b.time);
        return result;
    }
}
