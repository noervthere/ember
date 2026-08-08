//@ pragma UseQApplication
//@ pragma ShellId ambxst
//@ pragma DataDir $BASE/ambxst
//@ pragma StateDir $BASE/ambxst

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.bar
import qs.modules.bar.workspaces
import qs.modules.notifications
import qs.modules.widgets.dashboard.wallpapers
import "."
import "components"
import qs.modules.notch
import qs.modules.widgets.overview
import qs.modules.widgets.presets
import qs.modules.services
import qs.modules.corners
import qs.modules.frame
import qs.modules.components
import qs.modules.desktop
import qs.modules.lockscreen
import qs.modules.dock
import qs.modules.globals
import qs.modules.shell
import qs.config
import qs.modules.shell.osd
import "modules/tools"

ShellRoot {
    id: root

    ContextMenu {
        id: contextMenu
        screen: Quickshell.screens[0]
        Component.onCompleted: Visibilities.setContextMenu(contextMenu)
    }

    Variants {
        model: Quickshell.screens

        Loader {
            id: wallpaperLoader
            active: true
            required property ShellScreen modelData
            sourceComponent: Wallpaper {
                screen: wallpaperLoader.modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Loader {
            id: desktopLoader
            active: Config.desktop.enabled && SuspendManager.wakeReady
            required property ShellScreen modelData
            sourceComponent: Desktop {
                screen: desktopLoader.modelData
            }
        }
    }

    // Visual panel & reservations
    Variants {
        model: Quickshell.screens

        Item {
            id: screenShellContainer
            required property ShellScreen modelData

            // Panel components (Bar, Notch, Dock, Frame, Corners)
            UnifiedShellPanel {
                id: unifiedPanel
                targetScreen: screenShellContainer.modelData
            }

            Loader {
                active: Config.theme.enableCorners && Config.roundness > 0
                sourceComponent: ScreenCorners {
                    screen: screenShellContainer.modelData
                }
            }

            // Exclusive zone reservations
            ReservationWindows {
                screen: screenShellContainer.modelData

                // Bar status for reservations
                barEnabled: {
                    const list = (Config.bar && Config.bar.screenList !== undefined ? Config.bar.screenList : []);
                    return (!list || list.length === 0 || list.indexOf(screen.name) !== -1);
                }
                barPosition: unifiedPanel.barPosition
                barPinned: unifiedPanel.pinned
                barSize: (unifiedPanel.barPosition === "left" || unifiedPanel.barPosition === "right") ? unifiedPanel.barTargetWidth : unifiedPanel.barTargetHeight
                barOuterMargin: unifiedPanel.barOuterMargin

                // Dock status for reservations
                dockEnabled: {
                    if (!((Config.dock && Config.dock.enabled !== undefined ? Config.dock.enabled : false)) || (Config.dock && Config.dock.theme !== undefined ? Config.dock.theme : "default") === "integrated")
                        return false;

                    const list = (Config.dock && Config.dock.screenList !== undefined ? Config.dock.screenList : []);
                    if (!list || list.length === 0)
                        return true;
                    return list.indexOf(screenShellContainer.modelData.name) !== -1;
                }
                dockPosition: unifiedPanel.dockPosition
                dockPinned: unifiedPanel.dockPinned
                dockHeight: unifiedPanel.dockHeight
                containBar: unifiedPanel.containBar

                frameEnabled: (Config.bar && Config.bar.frameEnabled !== undefined ? Config.bar.frameEnabled : false)
                frameThickness: (Config.bar && Config.bar.frameThickness !== undefined ? Config.bar.frameThickness : 6)

                // Sidebar status for reservations
                sidebarEnabled: GlobalStates.assistantVisible && screenShellContainer.modelData.name === GlobalStates.assistantScreenName
                sidebarPinned: GlobalStates.assistantPinned
                sidebarWidth: GlobalStates.assistantWidth
                sidebarPosition: GlobalStates.assistantPosition
            }
        }
    }

    // Overview popup
    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = (Config.bar && Config.bar.screenList !== undefined ? Config.bar.screenList : []);
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.indexOf(screen.name) !== -1);
        }

        Loader {
            id: overviewLoader
            active: ((Config.overview && Config.overview.enabled !== undefined ? Config.overview.enabled : true)) && SuspendManager.wakeReady && (Visibilities.getForScreen(modelData.name) ? Visibilities.getForScreen(modelData.name).overview : false)
            required property ShellScreen modelData
            sourceComponent: OverviewPopup {
                screen: overviewLoader.modelData
            }
        }
    }

    // Presets popup
    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = (Config.bar && Config.bar.screenList !== undefined ? Config.bar.screenList : []);
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.indexOf(screen.name) !== -1);
        }

        Loader {
            id: presetsLoader
            active: SuspendManager.wakeReady && (Visibilities.getForScreen(modelData.name) ? Visibilities.getForScreen(modelData.name).presets : false)
            required property ShellScreen modelData
            sourceComponent: PresetsPopup {
                screen: presetsLoader.modelData
            }
        }
    }

    // Secure WlSessionLock lockscreen
    WlSessionLock {
        id: sessionLock
        locked: GlobalStates.lockscreenVisible

        // Surface auto-created per screen
        LockScreen {}
    }

    CompositorConfig {
        id: compositorConfig
    }

    // Screenshot tool
    Variants {
        model: Quickshell.screens

        Loader {
            id: screenshotLoader
            active: GlobalStates.screenshotToolVisible
            required property ShellScreen modelData
            sourceComponent: ScreenshotTool {
                targetScreen: screenshotLoader.modelData
            }
        }
    }

    // Screenshot preview overlay
    Variants {
        model: Quickshell.screens

        Loader {
            id: screenshotOverlayLoader
            active: SuspendManager.wakeReady
            required property ShellScreen modelData
            sourceComponent: ScreenshotOverlay {
                targetScreen: screenshotOverlayLoader.modelData
            }
        }
    }

    // Screen recording tool
    Loader {
        id: screenRecordLoader
        active: SuspendManager.wakeReady && GlobalStates.screenRecordToolVisible
        source: "modules/tools/ScreenrecordTool.qml"

        onLoaded: {
            if (GlobalStates.screenRecordToolVisible && item) {
                item.open();
            }
        }

        Connections {
            target: GlobalStates
            function onScreenRecordToolVisibleChanged() {
                if (screenRecordLoader.status === Loader.Ready) {
                    if (GlobalStates.screenRecordToolVisible) {
                        screenRecordLoader.item.open();
                    } else {
                        screenRecordLoader.item.close();
                    }
                }
            }
        }

        Connections {
            target: screenRecordLoader.item
            ignoreUnknownSignals: true
            function onVisibleChanged() {
                if (!screenRecordLoader.item.visible && GlobalStates.screenRecordToolVisible) {
                    GlobalStates.screenRecordToolVisible = false;
                }
            }
        }
    }

    // Mirror tool
    Loader {
        id: mirrorLoader
        active: SuspendManager.wakeReady && GlobalStates.mirrorWindowVisible
        source: "modules/tools/MirrorWindow.qml"
    }

    // Settings
    Loader {
        id: settingsWindowLoader
        active: SuspendManager.wakeReady && GlobalStates.settingsWindowVisible
        source: "modules/widgets/config/SettingsWindow.qml"
    }

    // On-screen display
    Variants {
        model: Quickshell.screens

        Loader {
            id: osdLoader
            active: SuspendManager.wakeReady
            required property ShellScreen modelData
            sourceComponent: OSD {
                targetScreen: osdLoader.modelData
            }
        }
    }

    // Init clipboard service
    Connections {
        target: ClipboardService
        function onListCompleted() {
        // Service initialized and ready
        }
    }

    // Force service init at startup but defer it slightly so it doesn't block the UI
    QtObject {
        id: serviceInitializer

        Component.onCompleted: {
            // Critical services — init immediately (next tick)
            Qt.callLater(() => {
                let _ = CaffeineService.inhibit;
                _ = IdleService.lockCmd; // Force init
                _ = GlobalShortcuts.appId; // Force init (IPC pipe listener)
            });
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "m3qs"
            exclusionMode: ExclusionMode.Ignore

            color: "transparent"

            anchors {
                top: Config.anchorPosition === "topLeft" || Config.anchorPosition === "topRight"
                bottom: Config.anchorPosition === "bottomLeft" || Config.anchorPosition === "bottomRight"
                left: Config.anchorPosition === "topLeft" || Config.anchorPosition === "bottomLeft"
                right: Config.anchorPosition === "topRight" || Config.anchorPosition === "bottomRight"
            }
            margins {
                top: Config.anchorPosition === "center" ? 0 : Config.marginTop
                bottom: Config.anchorPosition === "center" ? 0 : Config.marginBottom
                left: Config.anchorPosition === "center" ? 0 : Config.marginLeft
                right: Config.anchorPosition === "center" ? 0 : Config.marginRight
            }

            implicitWidth:  blurWrapper.implicitWidth
            implicitHeight: blurWrapper.implicitHeight

            property date currentTime: new Date()
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: root.currentTime = new Date()
            }

            MotionBlurWrapper {
                id: blurWrapper
                anchors.centerIn: parent
                implicitWidth:  variantLoader.item ? variantLoader.item.implicitWidth  : 260
                implicitHeight: variantLoader.item ? variantLoader.item.implicitHeight : 260
                velocityHint: variantLoader.item && variantLoader.item.blurVelocity
                ? variantLoader.item.blurVelocity
                : Qt.vector2d(0, 0)

                Loader {
                    id: variantLoader
                    anchors.fill: parent
                    sourceComponent: {
                        switch (Config.variant) {
                            case "scalloped": return scallopedComponent
                            case "pill":      return pillComponent
                            case "world":     return worldComponent
                            case "stacked":
                            default:          return stackedComponent
                        }
                    }
                    onLoaded: {
                        if (item.hasOwnProperty("currentTime"))
                            item.currentTime = Qt.binding(function() { return root.currentTime })
                    }
                }
            }
            Component { id: scallopedComponent; ScallopedAnalogClock {} }
            Component { id: stackedComponent; StackedDigitalClock {} }
            Component { id: pillComponent; PillDigitalClock {} }
            Component { id: worldComponent; WorldClock {} }
        }
    }


    // Non-critical services — defer 2s after startup
    Timer {
        interval: 2000
        running: true
        onTriggered: {
            let _ = NightLightService.active;
            _ = GameModeService.toggled;
        }
    }
}
