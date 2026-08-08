pragma Singleton
import QtQuick
import "."
import "themes"

QtObject {
    id: colors

    function _p() { return Themes.palettes[Config.theme] || Themes.palettes["pixel-blue"] }

    readonly property color primary: _p().primary
    readonly property color primaryContainer: _p().primaryContainer

    readonly property color secondary: _p().secondary
    readonly property color secondaryContainer: _p().secondaryContainer

    readonly property color tertiary: _p().tertiary
    readonly property color tertiaryContainer: _p().tertiaryContainer

    readonly property color surface: _p().surface
    readonly property color surfaceContainerLowest: _p().surfaceContainerLowest
    readonly property color surfaceContainerLow: _p().surfaceContainerLow
    readonly property color surfaceContainer: _p().surfaceContainer
    readonly property color surfaceContainerHigh: _p().surfaceContainerHigh
    readonly property color surfaceContainerHighest: _p().surfaceContainerHighest
    readonly property color outline: _p().outline
    readonly property color outlineVariant: _p().outlineVariant

    readonly property color error: _p().error
    readonly property color errorContainer: _p().errorContainer

    readonly property QtObject onRef: QtObject {
        id: onRef
        readonly property color primary: _p().onPrimary
        readonly property color primaryContainer: _p().onPrimaryContainer
        readonly property color secondary: _p().onSecondary
        readonly property color secondaryContainer: _p().onSecondaryContainer
        readonly property color tertiary: _p().onTertiary
        readonly property color tertiaryContainer: _p().onTertiaryContainer
        readonly property color surface: _p().onSurface
        readonly property color surfaceVariant: _p().onSurfaceVariant
        readonly property color error: _p().onError
        readonly property color errorContainer: _p().onErrorContainer
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
