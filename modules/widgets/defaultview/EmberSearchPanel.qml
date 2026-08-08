import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

// Ember Search — nixpkgs lookup via Nixhub/devbox API.
// Floating master-detail overlay: left search pane (~35%) | divider | right detail pane (~65%).
Item {
    id: panel
    anchors.fill: parent
    clip: true

    property bool panelVisible: false
    property bool isBottom: false

    property string queryText: ""
    property var searchResults: []
    property bool isSearching: false
    property string statusText: "Search nixpkgs"
    property string errorMessage: ""

    property bool detailMode: false
    property var selectedPackage: null
    property string selectedPackageVersion: ""
    property string copyToastMessage: ""

    // Keyboard-driven list selection
    property int selectedResultIndex: -1

    // Configurable (Config.notch.*)
    readonly property int debounceMs: Config.notch.searchDebounceMs ?? 300
    readonly property int maxResults: Config.notch.searchMaxResults ?? 20
    readonly property string installMethod: Config.notch.defaultInstallMethod ?? "flake"
    readonly property string nixConfigPath: Config.notch.nixConfigPath ?? "/etc/nixos/configuration.nix"
    readonly property string configEditor: Config.notch.configEditor ?? "nano"

    readonly property int targetLayoutHeight: 246

    onPanelVisibleChanged: {
        if (panelVisible && !detailMode)
            Qt.callLater(() => searchInputField.focusInput());
    }

    onDetailModeChanged: {
        if (!detailMode && panelVisible)
            Qt.callLater(() => searchInputField.focusInput());
    }

    onSearchResultsChanged: {
        if (detailMode)
            return;
        selectedResultIndex = searchResults.length > 0 ? 0 : -1;
    }

    Timer {
        id: debounceTimer
        interval: panel.debounceMs
        repeat: false
        onTriggered: panel.performSearch()
    }

    function onQueryInput(text) {
        panel.queryText = text;
        if (panel.detailMode)
            panel.detailMode = false;
        if (text.trim() === "") {
            debounceTimer.stop();
            panel.searchResults = [];
            panel.isSearching = false;
            panel.statusText = "Search nixpkgs";
            panel.errorMessage = "";
            return;
        }
        panel.isSearching = true;
        panel.statusText = "Searching…";
        debounceTimer.restart();
    }

    function performSearch() {
        let q = panel.queryText.trim();
        if (!q)
            return;

        const xhr = new XMLHttpRequest();
        xhr.open("GET", "https://search.devbox.sh/v2/search?q=" + encodeURIComponent(q));
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            panel.isSearching = false;
            if (xhr.status === 200) {
                try {
                    const data = JSON.parse(xhr.responseText);
                    let results = data.results || [];
                    if (panel.maxResults > 0 && results.length > panel.maxResults)
                        results = results.slice(0, panel.maxResults);
                    panel.searchResults = results;
                    panel.errorMessage = "";
                    panel.statusText = results.length === 0 ? "No packages" : (results.length + " found");
                } catch (e) {
                    panel.errorMessage = "Parse error";
                    panel.statusText = "Parse error";
                }
            } else if (xhr.status === 429) {
                panel.errorMessage = "Rate limited";
                panel.statusText = "Try again shortly";
            } else {
                panel.errorMessage = "Network error";
                panel.statusText = "Error " + xhr.status;
            }
        };
        xhr.send();
    }

    function selectPackage(pkg) {
        panel.selectedPackage = pkg;
        panel.selectedPackageVersion = "";
        panel.detailMode = true;
        panel.fetchPackageDetail(pkg.name);
    }

    function fetchPackageDetail(pkgName) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", "https://search.devbox.sh/v2/pkg?name=" + encodeURIComponent(pkgName));
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return;
            try {
                const data = JSON.parse(xhr.responseText);
                if (data.releases && data.releases.length > 0)
                    panel.selectedPackageVersion = data.releases[0].version || "";
            } catch (e) {}
        };
        xhr.send();
    }

    function getInstallCommand(pkgName) {
        const method = panel.installMethod;
        if (method === "nix-env")
            return "nix-env -iA nixpkgs." + pkgName;
        if (method === "devshell")
            return "nix shell nixpkgs#" + pkgName;
        return "nix profile install nixpkgs#" + pkgName;
    }

    Process {
        id: copyProcess
    }

    function copyToClipboard(text) {
        copyProcess.command = ["wl-copy", text];
        copyProcess.running = true;
        panel.copyToastMessage = "Copied";
        toastTimer.restart();
    }

    function openNixConfig() {
        const editor = panel.configEditor || "nano";
        const path = panel.nixConfigPath || "/etc/nixos/configuration.nix";
        const safePath = String(path).replace(/'/g, "'\\''");
        TerminalService.execDetached(editor + " '" + safePath + "'");
        if (panel.selectedPackage)
            panel.copyToClipboard(panel.selectedPackage.name);
        panel.copyToastMessage = "Opening config…";
        toastTimer.restart();
    }

    function clearSearch() {
        panel.detailMode = false;
        panel.searchInputField.clear();
    }

    // Keyboard-navigation helpers
    function moveSelectionDown() {
        if (searchResults.length === 0 || detailMode)
            return;
        selectedResultIndex = (selectedResultIndex + 1) % searchResults.length;
        resultsListView.positionViewAtIndex(selectedResultIndex, ListView.Contain);
    }
    function moveSelectionUp() {
        if (searchResults.length === 0 || detailMode)
            return;
        selectedResultIndex = (selectedResultIndex - 1 + searchResults.length) % searchResults.length;
        resultsListView.positionViewAtIndex(selectedResultIndex, ListView.Contain);
    }
    function activateSelection() {
        if (detailMode)
            return;
        if (selectedResultIndex >= 0 && selectedResultIndex < searchResults.length)
            selectPackage(searchResults[selectedResultIndex]);
    }
    function exitDetail() {
        panel.detailMode = false;
    }

    Timer {
        id: toastTimer
        interval: 1800
        onTriggered: panel.copyToastMessage = ""
    }

    // =========================================================================
    // PARALLAX + CURSOR GLOW (same language as the music panels)
    // =========================================================================
    property real _mouseNormX: 0
    property real _mouseNormY: 0
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
        acceptedButtons: Qt.NoButton
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

    Image {
        id: cursorGlow
        width: 300
        height: 300
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
            const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300">
                <defs><radialGradient id="g" cx="50%" cy="50%" r="50%">
                    <stop offset="0%" stop-color="${color}" stop-opacity="0.24"/>
                    <stop offset="45%" stop-color="${color}" stop-opacity="0.07"/>
                    <stop offset="100%" stop-color="${color}" stop-opacity="0"/>
                </radialGradient></defs>
                <circle cx="150" cy="150" r="150" fill="url(#g)"/>
            </svg>`;
            return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
        }
        sourceSize: Qt.size(300, 300)
        smooth: true
        asynchronous: true
    }

    // =========================================================================
    // OUTER FRAME + SHARED BLUR (continuity with the notch glass)
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
        radius: Styling.radius(4)

        Rectangle {
            id: mainBgCrisp
            anchors.fill: parent
            anchors.margins: -16
            gradient: Gradient {
                GradientStop { position: 0.0; color: Colors.surfaceContainerHighest }
                GradientStop { position: 1.0; color: Colors.surface }
            }
            opacity: 0.85
            transform: Translate { x: panel._mouseNormX * -6; y: panel._mouseNormY * -4 }
        }
        Rectangle {
            id: mainBgBlurredSource
            anchors.fill: parent
            anchors.margins: -16
            color: Colors.surfaceContainer
            visible: false
            transform: Translate { x: panel._mouseNormX * -6; y: panel._mouseNormY * -4 }
        }
        MultiEffect {
            id: mainBgBlurred
            anchors.fill: parent
            source: mainBgBlurredSource
            blurEnabled: true
            blurMax: 28
            blur: 0.85
            brightness: -0.12
            saturation: 0.12
            opacity: 0.85
            visible: panel.panelVisible
        }
    }

    // =========================================================================
    // MASTER-DETAIL LAYOUT
    // =========================================================================
    ColumnLayout {
        id: mainLayout
        anchors.top: panel.isBottom ? undefined : parent.top
        anchors.bottom: panel.isBottom ? parent.bottom : undefined
        anchors.left: parent.left
        anchors.right: parent.right
        height: panel.targetLayoutHeight
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: panel.isBottom ? 0 : 12
        anchors.bottomMargin: panel.isBottom ? 12 : 0
        spacing: 8
        visible: opacity > 0
        opacity: panel.panelVisible ? 1.0 : 0.0

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
        }

        // ----- TOP: unified search bar, spanning both panes below -----
        StyledRect {
            id: searchBarCard
            variant: "pane"
            backgroundOpacity: 0.72
            enableBorder: true
            radius: Styling.radius(3)
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            clip: true
            visible: panel.panelVisible

            transform: Translate { x: panel._mouseNormX * 5; y: panel._mouseNormY * 3 }

            FrostedWindow {
                anchors.fill: parent
                z: -1
                blurSource: mainBgBlurred
                mapTarget: outerFramedCard
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                SearchInput {
                    id: searchInputField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    placeholderText: "Find a package…"
                    iconText: Icons.cube
                    onSearchTextChanged: text => panel.onQueryInput(text)
                    onDownPressed: panel.moveSelectionDown()
                    onUpPressed: panel.moveSelectionUp()
                    onAccepted: panel.activateSelection()
                    onEscapePressed: {
                        if (panel.detailMode)
                            panel.exitDetail();
                    }
                }

                // Circular clear button — inert until there's something to clear
                StyledRect {
                    id: clearActionBtn
                    readonly property bool hasQuery: panel.queryText.trim() !== ""
                    variant: hasQuery && clearBtnArea.containsMouse ? "focus" : "common"
                    opacity: hasQuery ? 1.0 : 0.4
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation { duration: 150 }
                    }
                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: 150 }
                    }
                    MouseArea {
                        id: clearBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: clearActionBtn.hasQuery
                        cursorShape: clearActionBtn.hasQuery ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: panel.clearSearch()
                    }
                    Text {
                        anchors.centerIn: parent
                        text: Icons.brush
                        font.family: Icons.font
                        font.pixelSize: 15
                        color: clearActionBtn.hasQuery ? clearActionBtn.item : Colors.secondary
                    }
                }
            }
        }

        // ----- BOTTOM: results | preview split -----
        RowLayout {
            id: splitRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ----- LEFT: master pane (~35%) -----
            StyledRect {
                id: masterPane
                variant: "pane"
                backgroundOpacity: 0.72
                enableBorder: true
                radius: Styling.radius(3)
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                clip: true
                visible: panel.panelVisible

                transform: Translate { x: panel._mouseNormX * 5; y: panel._mouseNormY * 3 }

                FrostedWindow {
                    anchors.fill: parent
                    z: -1
                    blurSource: mainBgBlurred
                    mapTarget: outerFramedCard
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // List header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            radius: 3
                            color: Colors.primary
                        }
                        Text {
                            text: "RESULTS"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            font.letterSpacing: 2.5
                            font.weight: Font.Medium
                            color: Colors.secondary
                        }
                        Item { Layout.fillWidth: true }

                        StyledRect {
                            visible: panel.isSearching
                            variant: "focus"
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: Styling.radius(0)
                            Text {
                                anchors.centerIn: parent
                                text: Icons.spinnerGap
                                font.family: Icons.font
                                font.pixelSize: 11
                                color: Colors.primary
                                RotationAnimation on rotation {
                                    running: panel.isSearching
                                    loops: Animation.Infinite
                                    from: 0; to: 360; duration: 900
                                }
                            }
                        }
                        Text {
                            visible: !panel.isSearching && panel.searchResults.length > 0
                            text: panel.searchResults.length
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            font.bold: true
                            color: Colors.primary
                            opacity: 0.9
                        }
                    }

                    // List
                    ListView {
                        id: resultsListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: panel.searchResults
                        clip: true
                        focus: true
                        spacing: 3
                        visible: panel.searchResults.length > 0

                        currentIndex: panel.selectedResultIndex
                        highlightFollowsCurrentItem: true
                        highlightMoveDuration: Config.animDuration >> 1

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 4
                            contentItem: Rectangle {
                                color: Colors.overSurfaceVariant
                                opacity: 0.35
                                radius: 2
                            }
                        }

                        highlight: StyledRect {
                            width: resultsListView.width
                            variant: "primary"
                            radius: Styling.radius(2)
                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutQuart }
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0)
                                panel.selectedResultIndex = currentIndex;
                        }

                        delegate: Item {
                            id: resultRow
                            required property var modelData
                            required property int index
                            width: resultsListView.width
                            height: 46

                            readonly property bool isSelected: index === panel.selectedResultIndex
                            readonly property color fg: isSelected ? Styling.srItem("primary") : Colors.overSurface

                            StyledRect {
                                id: rowHoverBg
                                anchors.fill: parent
                                radius: Styling.radius(2)
                                variant: "common"
                                opacity: (!resultRow.isSelected && rowArea.containsMouse) ? 0.5 : 0.0
                                visible: opacity > 0
                                Behavior on opacity {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation { duration: 120 }
                                }
                            }

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    panel.selectedResultIndex = index;
                                    resultsListView.currentIndex = index;
                                    panel.activateSelection();
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 10
                                spacing: 10

                                StyledRect {
                                    id: rowIcon
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    radius: Styling.radius(-4)
                                    variant: resultRow.isSelected ? "overprimary" : "common"
                                    Behavior on color {
                                        enabled: Config.animDuration > 0
                                        ColorAnimation { duration: 160 }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.cube
                                        font.family: Icons.font
                                        font.pixelSize: 14
                                        color: rowIcon.item
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Bold
                                        color: resultRow.fg
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.summary || "No description"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-4)
                                        color: resultRow.fg
                                        opacity: resultRow.isSelected ? 0.8 : 0.45
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    // Empty list state
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6
                        visible: panel.searchResults.length === 0
                        Item { Layout.fillHeight: true }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Icons.cube
                            font.family: Icons.font
                            font.pixelSize: 22
                            color: Colors.overSurfaceVariant
                            opacity: 0.3
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 2
                            text: panel.queryText.trim() === ""
                                ? "Search the Nix index"
                                : (panel.isSearching ? "Searching…" : "No packages found")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overSurfaceVariant
                            opacity: 0.5
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "↑↓ move · Enter open"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            font.weight: Font.Medium
                            color: Colors.secondary
                            opacity: 0.5
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // ----- Divider -----
            Separator {
                vert: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.fillHeight: true
            }

            // ----- RIGHT: detail pane (~65%) -----
            StyledRect {
                id: detailPane
                variant: "pane"
                backgroundOpacity: 0.78
                enableBorder: true
                radius: Styling.radius(3)
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                clip: true

                transform: Translate { x: panel._mouseNormX * 3; y: panel._mouseNormY * 2 }

                FrostedWindow {
                    anchors.fill: parent
                    z: -1
                    blurSource: mainBgBlurred
                    mapTarget: outerFramedCard
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Eyebrow
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: panel.detailMode ? "PACKAGE" : "PREVIEW"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            font.letterSpacing: 2.5
                            font.weight: Font.Medium
                            color: Colors.secondary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: panel.copyToastMessage !== "" ? panel.copyToastMessage : (panel.errorMessage !== "" ? panel.errorMessage : panel.statusText)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            color: panel.errorMessage !== "" ? Colors.error : (panel.copyToastMessage !== "" ? Colors.primary : Colors.overSurfaceVariant)
                            opacity: 0.85
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                            Layout.maximumWidth: 180
                        }
                    }

                    // Placeholder when no package selected
                    ColumnLayout {
                        visible: !panel.detailMode
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8
                        Item { Layout.fillHeight: true }
                        StyledRect {
                            Layout.alignment: Qt.AlignHCenter
                            variant: "focus"
                            radius: 60
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            Text {
                                anchors.centerIn: parent
                                text: Icons.cube
                                font.family: Icons.font
                                font.pixelSize: 20
                                color: Colors.primary
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            horizontalAlignment: Text.AlignHCenter
                            text: "No package selected"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.DemiBold
                            color: Colors.overSurface
                            opacity: 0.85
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: "Results appear here as you type"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.overSurfaceVariant
                            opacity: 0.5
                        }
                        Item { Layout.fillHeight: true }
                    }

                    // Detail content
                    ColumnLayout {
                        visible: panel.detailMode
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8
                        opacity: panel.detailMode ? 1.0 : 0.0
                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutQuart }
                        }

                        // Name + version
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            StyledRect {
                                id: pkgIconTile
                                variant: "focus"
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: Styling.radius(2)
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.cube
                                    font.family: Icons.font
                                    font.pixelSize: 20
                                    color: Colors.primary
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.selectedPackage ? panel.selectedPackage.name : ""
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(3)
                                    font.weight: Font.DemiBold
                                    color: Colors.overSurface
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "nixpkgs # " + (panel.installMethod || "flake")
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.overSurfaceVariant
                                    opacity: 0.6
                                    elide: Text.ElideRight
                                }
                            }
                            StyledRect {
                                id: versionPill
                                variant: "primary"
                                radius: Styling.radius(2)
                                Layout.preferredHeight: 22
                                implicitWidth: verLabel.implicitWidth + 14
                                visible: panel.selectedPackageVersion !== ""
                                Text {
                                    id: verLabel
                                    anchors.centerIn: parent
                                    text: panel.selectedPackageVersion
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.bold: true
                                    color: versionPill.item
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: panel.selectedPackage ? (panel.selectedPackage.summary || "No description") : ""
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overSurfaceVariant
                            opacity: 0.75
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        StyledRect {
                            id: commandChip
                            variant: chipHover.hovered ? "focus" : "common"
                            radius: Styling.radius(2)
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            clip: true
                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation { duration: 150 }
                            }
                            HoverHandler { id: chipHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (panel.selectedPackage)
                                        panel.copyToClipboard(panel.getInstallCommand(panel.selectedPackage.name));
                                }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8
                                Text {
                                    text: "$"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.bold: true
                                    color: Colors.primary
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.selectedPackage ? panel.getInstallCommand(panel.selectedPackage.name) : ""
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: Colors.overSurface
                                    elide: Text.ElideMiddle
                                }
                                Text {
                                    text: Icons.copy
                                    font.family: Icons.font
                                    font.pixelSize: 12
                                    color: Colors.overSurfaceVariant
                                    opacity: chipHover.hovered ? 0.8 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Actions
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            StyledRect {
                                id: copyBtn
                                variant: "primary"
                                radius: Styling.radius(2)
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (panel.selectedPackage)
                                            panel.copyToClipboard(panel.getInstallCommand(panel.selectedPackage.name));
                                    }
                                }
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: Icons.copy; font.family: Icons.font; font.pixelSize: 14; color: copyBtn.item }
                                    Text { text: "Copy"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-1); font.weight: Font.Bold; color: copyBtn.item }
                                }
                            }
                            StyledRect {
                                id: configBtn
                                variant: "focus"
                                radius: Styling.radius(2)
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.openNixConfig()
                                }
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: Icons.gear; font.family: Icons.font; font.pixelSize: 13; color: configBtn.item }
                                    Text { text: "Config"; font.family: Config.theme.font; font.pixelSize: Styling.fontSize(-2); font.weight: Font.Medium; color: configBtn.item }
                                }
                            }
                            StyledRect {
                                id: backBtn
                                variant: "common"
                                radius: Styling.radius(2)
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.detailMode = false
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.caretLeft
                                    font.family: Icons.font
                                    font.pixelSize: 15
                                    color: Colors.overSurface
                                }
                            }
                        }
                    }
                }
            }
        } // end splitRow
    }
}