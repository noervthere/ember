pragma Singleton
import QtQuick
import Quickshell.Io
import "."
import "themes"

QtObject {
    id: colors

    property var _data: ({})
    readonly property var _fallback: Themes.palettes[Config.theme] || Themes.palettes["pixel-blue"]
  
    property string anchorPosition: "topleft"

property FileView colorFile: FileView {
        id: colorFile
        path: "/home/ovt/.cache/ambxst/colors.json"
        
        // Tells Quickshell to monitor the file for modifications
        watchChanges: true 

        // Emitted when the file on disk changes; reload() fetches the new data
        onFileChanged: {
            reload()
        }

        // Emitted when the loaded text updates
        onTextChanged: {
            // Note: text() is called as a function in Quickshell
            let txt = text().trim(); 
            if (txt !== "") {
                try {
                    let parsed = JSON.parse(txt);
                    if (parsed && typeof parsed === "object" && parsed.primary) {
                        colors._data = parsed;
                    }
                } catch (e) {
                    // Ignore mid-write truncation errors
                }
            }
        }
    }
    
    // Base color roles mapped to colors.json with intelligent fallbacks
    readonly property color primary: _data.primary || _fallback.primary
    readonly property color primaryContainer: _data.primaryContainer || _fallback.primaryContainer

    readonly property color secondary: _data.secondary || _fallback.secondary
    readonly property color secondaryContainer: _data.secondaryContainer || _fallback.secondaryContainer

    readonly property color tertiary: _data.tertiary || _fallback.tertiary
    readonly property color tertiaryContainer: _data.tertiaryContainer || _fallback.tertiaryContainer

    readonly property color surface: _data.surface || _fallback.surface
    readonly property color surfaceContainerLowest: _data.surfaceContainerLowest || _fallback.surfaceContainerLowest
    readonly property color surfaceContainerLow: _data.surfaceContainerLow || _fallback.surfaceContainerLow
    readonly property color surfaceContainer: _data.surfaceContainer || _fallback.surfaceContainer
    readonly property color surfaceContainerHigh: _data.surfaceContainerHigh || _fallback.surfaceContainerHigh
    readonly property color surfaceContainerHighest: _data.surfaceContainerHighest || _fallback.surfaceContainerHighest
    
    // Explicitly mapping surfaceVariant from json containers so it doesn't stay static
    readonly property color surfaceVariant: _data.surfaceVariant || _data.surfaceContainerHigh || _fallback.surfaceVariant

    readonly property color outline: _data.outline || _fallback.outline
    readonly property color outlineVariant: _data.outlineVariant || _fallback.outlineVariant

    readonly property color error: _data.error || _fallback.error
    readonly property color errorContainer: _data.errorContainer || _fallback.errorContainer

    readonly property QtObject onRef: QtObject {
        id: onRef
        readonly property color primary: colors._data.onPrimary || colors._fallback.onPrimary
        readonly property color primaryContainer: colors._data.onPrimaryContainer || colors._fallback.onPrimaryContainer
        readonly property color secondary: colors._data.onSecondary || colors._fallback.onSecondary
        readonly property color secondaryContainer: colors._data.onSecondaryContainer || colors._fallback.onSecondaryContainer
        readonly property color tertiary: colors._data.onTertiary || colors._fallback.onTertiary
        readonly property color tertiaryContainer: colors._data.onTertiaryContainer || colors._fallback.onTertiaryContainer
        readonly property color surface: colors._data.onSurface || colors._fallback.onSurface
        readonly property color surfaceVariant: colors._data.onSurfaceVariant || colors._fallback.onSurfaceVariant
        readonly property color error: colors._data.onError || colors._fallback.onError
        readonly property color errorContainer: colors._data.onErrorContainer || colors._fallback.onErrorContainer
    }

    property alias onPrimary: onRef.primary
    property alias onPrimaryContainer: onRef.primaryContainer
    property alias onSecondary: onRef.secondary
    property alias onSecondaryContainer: onRef.secondaryContainer
    property alias onTertiary: onRef.tertiary
    property alias onTertiaryContainer: onRef.tertiaryContainer
    property alias onSurface: onRef.surface
    property alias onSurfaceVariant: onRef.surfaceVariant
    property alias onError: onRef.error
    property alias onErrorContainer: onRef.errorContainer
}   