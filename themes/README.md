# Pre-built Color Themes

Themes are switched via `Config.qml` — set the `theme` property to any key below:

```qml
property string theme: "emerald-green"
```

| Key | Primary | Description |
|---|---|---|
| `pixel-blue` | `#D0BCFF` | Android dynamic blue (default) |
| `emerald-green` | `#6BBF8A` | Botanical green |
| `amethyst-purple` | `#B59CFF` | Rich violet |
| `crimson-rose` | `#FFB4AB` | Warm red |
| `amber-sunset` | `#FFB870` | Golden orange |
| `teal-cyan` | `#78D8D8` | Ocean teal |
| `charcoal` | `#9E9E9E` | Monochrome greyscale |
| `nordic-slate` | `#8EADC8` | Cool blue-grey |

All palettes live in [`Themes.qml`](Themes.qml). To add a custom palette, insert a new entry into the `palettes` object with the same 16-token Material 3 structure.

Matugen users: use any palette as a base or generate fresh ones with the template at `matugen/templates/colors.qml`.
