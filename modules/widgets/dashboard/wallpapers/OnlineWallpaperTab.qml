import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services

Item {
    id: root

    property string currentScreenName: ""
    property bool renderImages: false

    Timer {
        id: imageRenderDelayTimer
        interval: Config.animDuration > 0 ? Config.animDuration + 50 : 0
        repeat: false
        onTriggered: root.renderImages = true
    }

    onVisibleChanged: {
        if (visible) {
            root.renderImages = false;
            imageRenderDelayTimer.restart();
        } else {
            root.renderImages = false;
            imageRenderDelayTimer.stop();
        }
    }

    Component.onCompleted: {
        if (visible) {
            imageRenderDelayTimer.restart();
        }
    }

    function focusSearchInput() {
        if (searchInput && searchInput.focusInput)
            searchInput.focusInput();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Top Control Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Search Bar
            SearchInput {
                id: searchInput
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                placeholderText: "Search wallpapers..."
                iconText: Icons.globe

                onAccepted: {
                    OnlineWallpaperService.search(text, 1);
                }

                onSearchTextChanged: {
                    searchDebounceTimer.restart();
                }
            }

            Timer {
                id: searchDebounceTimer
                interval: 500
                repeat: false
                onTriggered: {
                    OnlineWallpaperService.search(searchInput.text, 1);
                }
            }

            // Source Selector Toggle
            StyledRect {
                Layout.preferredWidth: 160
                Layout.preferredHeight: 38
                variant: "internalbg"
                radius: Styling.radius(4)

                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    // Wallhaven Button
                    StyledRect {
                        width: (parent.width - 3) / 2
                        height: parent.height
                        radius: Styling.radius(3)
                        variant: OnlineWallpaperService.source === "wallhaven" ? "primary" : "common"

                        Text {
                            anchors.centerIn: parent
                            text: "Wallhaven"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.DemiBold
                            color: OnlineWallpaperService.source === "wallhaven" ? Styling.srItem("primary") : Colors.overBackground
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: OnlineWallpaperService.setSource("wallhaven")
                        }
                    }

                    // Konachan Button
                    StyledRect {
                        width: (parent.width - 3) / 2
                        height: parent.height
                        radius: Styling.radius(3)
                        variant: OnlineWallpaperService.source === "konachan" ? "primary" : "common"

                        Text {
                            anchors.centerIn: parent
                            text: "Konachan"
                            font.family: Styling.defaultFont
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.DemiBold
                            color: OnlineWallpaperService.source === "konachan" ? Styling.srItem("primary") : Colors.overBackground
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: OnlineWallpaperService.setSource("konachan")
                        }
                    }
                }
            }

            // Pagination Controls
            RowLayout {
                spacing: 4

                // Prev Page
                StyledRect {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 38
                    variant: prevMouse.hovered ? "focus" : "common"
                    radius: Styling.radius(4)
                    opacity: OnlineWallpaperService.currentPage > 1 ? 1.0 : 0.4

                    Text {
                        anchors.centerIn: parent
                        text: Icons.caretLeft
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: Colors.overBackground
                    }

                    HoverHandler { id: prevMouse }
                    TapHandler {
                        onTapped: OnlineWallpaperService.prevPage()
                    }
                }

                Text {
                    text: OnlineWallpaperService.currentPage + " / " + OnlineWallpaperService.lastPage
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overBackground
                    Layout.alignment: Qt.AlignVCenter
                }

                // Next Page
                StyledRect {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 38
                    variant: nextMouse.hovered ? "focus" : "common"
                    radius: Styling.radius(4)
                    opacity: OnlineWallpaperService.currentPage < OnlineWallpaperService.lastPage ? 1.0 : 0.4

                    Text {
                        anchors.centerIn: parent
                        text: Icons.caretRight
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: Colors.overBackground
                    }

                    HoverHandler { id: nextMouse }
                    TapHandler {
                        onTapped: OnlineWallpaperService.nextPage()
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignRight
            text: "right click to save"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            font.italic: true
            color: Colors.overBackground
            opacity: 0.35
        }

        // Search Query Indicator
        RowLayout {
            Layout.fillWidth: true
            visible: OnlineWallpaperService.query.trim() !== ""
            spacing: 6

            Text {
                text: "Searching for:"
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Medium
                color: Colors.overBackground
                opacity: 0.7
            }

            Text {
                text: '"' + OnlineWallpaperService.query + '"'
                font.family: Styling.defaultFont
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Bold
                color: Colors.primary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Clear Search Button
            StyledRect {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: Styling.radius(2)
                variant: clearSearchHover.hovered ? "focus" : "common"

                Text {
                    anchors.centerIn: parent
                    text: Icons.cancel
                    font.family: Icons.font
                    font.pixelSize: 11
                    color: Colors.overBackground
                }

                HoverHandler { id: clearSearchHover }
                TapHandler {
                    onTapped: {
                        searchInput.clear();
                        OnlineWallpaperService.search("", 1);
                    }
                }
            }
        }

        // Main Grid Content Area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading View
            StyledRect {
                anchors.fill: parent
                variant: "internalbg"
                radius: Styling.radius(4)
                visible: OnlineWallpaperService.isLoading && OnlineWallpaperService.wallpapers.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Icons.spinnerGap
                        font.family: Icons.font
                        font.pixelSize: 32
                        color: Colors.primary

                        RotationAnimator on rotation {
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: OnlineWallpaperService.isLoading
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: OnlineWallpaperService.query.trim() !== "" ? ("Fetching wallpapers for \"" + OnlineWallpaperService.query + "\"...") : "Fetching wallpapers..."
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                    }
                }
            }

            // Error View
            StyledRect {
                anchors.fill: parent
                variant: "internalbg"
                radius: Styling.radius(4)
                visible: !OnlineWallpaperService.isLoading && OnlineWallpaperService.lastError !== "" && OnlineWallpaperService.wallpapers.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Icons.alert
                        font.family: Icons.font
                        font.pixelSize: 32
                        color: Colors.red
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: OnlineWallpaperService.lastError
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                    }

                    Button {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Retry"
                        onClicked: OnlineWallpaperService.search(searchInput.text, OnlineWallpaperService.currentPage)
                    }
                }
            }

            // Empty View
            StyledRect {
                anchors.fill: parent
                variant: "internalbg"
                radius: Styling.radius(4)
                visible: !OnlineWallpaperService.isLoading && OnlineWallpaperService.lastError === "" && OnlineWallpaperService.wallpapers.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Icons.image
                        font.family: Icons.font
                        font.pixelSize: 32
                        color: Colors.overBackground
                        opacity: 0.5
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No wallpapers found"
                        font.family: Styling.defaultFont
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overBackground
                        opacity: 0.7
                    }
                }
            }

            // Wallpaper Cards Grid
            GridView {
                id: gridView
                anchors.fill: parent
                cellWidth: width / 3
                cellHeight: 140
                clip: true
                visible: OnlineWallpaperService.wallpapers.length > 0

                model: OnlineWallpaperService.wallpapers

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: gridView.cellWidth
                    height: gridView.cellHeight

                    readonly property bool isDownloadingThis: OnlineWallpaperService.isDownloading && (OnlineWallpaperService.downloadingUrl === modelData.fullUrl || GlobalStates.onlineWallpaperDownloadingUrl === modelData.fullUrl)

                    Item {
                        anchors.fill: parent
                        anchors.margins: 4

                        StyledRect {
                            id: cardContainer
                            anchors.fill: parent
                            variant: cardHover.hovered ? "focus" : "internalbg"
                            radius: Styling.radius(4)

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: root.renderImages ? modelData.previewUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                opacity: (status === Image.Ready && root.renderImages) ? 1.0 : 0.0

                                Behavior on opacity {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                }

                                layer.enabled: true
                            }

                            // Card overlay badge (resolution / info)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 22
                                color: "#cc000000"
                                radius: Styling.radius(2)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6

                                    Text {
                                        text: modelData.resolution !== "" ? modelData.resolution : modelData.source
                                        font.family: Styling.defaultFont
                                        font.pixelSize: Styling.fontSize(-3)
                                        color: "#ffffff"
                                        font.weight: Font.Medium
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.source === "wallhaven" ? "WH" : "KC"
                                        font.family: Styling.defaultFont
                                        font.pixelSize: Styling.fontSize(-4)
                                        color: Colors.primary
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Downloading Loading Overlay on Card
                            StyledRect {
                                anchors.fill: parent
                                variant: "popup"
                                opacity: isDownloadingThis ? 0.85 : 0.0
                                visible: opacity > 0

                                Behavior on opacity {
                                    NumberAnimation { duration: 200 }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Icons.spinnerGap
                                        font.family: Icons.font
                                        font.pixelSize: 20
                                        color: Colors.primary

                                        RotationAnimator on rotation {
                                            from: 0
                                            to: 360
                                            duration: 800
                                            loops: Animation.Infinite
                                            running: isDownloadingThis
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Downloading..."
                                        font.family: Styling.defaultFont
                                        font.pixelSize: Styling.fontSize(-3)
                                        color: Colors.overBackground
                                    }
                                }
                            }

                            HoverHandler { id: cardHover }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        OnlineWallpaperService.saveToCollection(modelData);
                                    } else {
                                        OnlineWallpaperService.downloadAndApply(modelData, currentScreenName);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
