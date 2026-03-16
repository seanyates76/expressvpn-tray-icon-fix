# ExpressVPN Tray Icon Fix

This project improves ExpressVPN's Linux tray icons. It ships replacement tray
assets plus a runtime hook that keeps the tray icon in sync with the current
light or dark system theme.

Current scope:

- first public release
- Arch package first
- Linux runtime mod
- compatibility tracked by tested combinations only

## Preview

<table>
  <tr>
    <th>Before</th>
    <th>After</th>
  </tr>
  <tr>
    <td><img src="docs/assets/Before.png" alt="Original ExpressVPN tray icon" width="576"></td>
    <td><img src="docs/assets/After.png" alt="Improved ExpressVPN tray icon" width="576"></td>
  </tr>
</table>

## Install

### Arch Linux

Preferred end-user path:

1. Download the latest `expressvpn-tray-icon-fix-*.pkg.tar.zst` from GitHub Releases.
2. Install it with:

```bash
sudo pacman -U ./expressvpn-tray-icon-fix-0.1.0-1-x86_64.pkg.tar.zst
```

What the package does:

- installs the runtime under `/usr/lib/expressvpn-tray-icon-fix`
- installs the launcher command `expressvpn-tray-icon-fix`
- automatically hooks the normal `ExpressVPN` launcher path for the installing user
- keeps menu search results under `ExpressVPN`, not a second helper app name

Manual page:

- `man expressvpn-tray-icon-fix`

## Desktop Integration Model

- the package installs its own desktop entry at
  `/usr/share/applications/expressvpn-tray-icon-fix.desktop`
- package integration then manages per-user overrides at
  `~/.local/share/applications/expressvpn.desktop` and
  `~/.config/autostart/expressvpn-client.desktop`
- the user-visible launcher remains `ExpressVPN` in menu search

### Build Locally

For local packaging from a working tree:

```bash
cd packaging/arch
makepkg -fsi
```

Or from the repo root:

```bash
make package-arch-install
```

### Other Distros

Not packaged yet.

The runtime mod may work on other Linux distros if the installed ExpressVPN GUI
matches the assumptions in `docs/COMPATIBILITY.md`, but only tested
combinations are claimed and only Arch packaging is provided right now.

Compatibility tracking:

- `docs/COMPATIBILITY.md`

Trust and verification:

- `docs/TRANSPARENCY.md`

## Runtime Model

- the preload hook follows the system theme and live-switches the tray icon
- live tray refresh is file-backed instead of patching vendor files in place
- the current packaged launcher starts the ExpressVPN GUI under
  `XDG_SESSION_TYPE=X11`
- Wayland behavior is not yet verified
- the runtime ships both style options:
  - `colored`
  - `monochrome`

## Styles

The packaged launcher defaults to `colored`.

To persist a style choice:

```bash
expressvpn-tray-icon-fix --set-style colored
expressvpn-tray-icon-fix --set-style monochrome
```

The persisted config file is:

- `~/.config/expressvpn-tray-icon-fix/style`

Accepted values:

- `colored`
- `monochrome`

If the standard `ExpressVPN` launcher ever needs to be recreated, run:

```bash
expressvpn-tray-icon-fix --repair-integration
```

## Development

The custom `make install` flow is only for working-tree development and testing.

```bash
make install STYLE=colored
make install STYLE=monochrome
make uninstall
```

Helper targets:

- `make package-arch`
- `make package-arch-install`
- `make srcinfo`
- `make extract`

Arch packaging files:

- `packaging/arch/PKGBUILD`
- `packaging/arch/.SRCINFO`

Developer-only launcher/debug options:

- `expressvpn-tray-icon-fix -h`
- `expressvpn-tray-icon-fix --foreground`
- `EXPRESSVPN_TRAY_ICON_FIX_STYLE=monochrome expressvpn-tray-icon-fix`

## Asset Workflow

Refresh the themed asset sets with:

```bash
./scripts/build_tray_variants.sh
```

The shipped tray assets live under:

- `resources/themed/img/`

## Extraction

This is dev-only tooling for maintainers and forks.

The embedded tray PNGs can be re-extracted from the ExpressVPN client with:

```bash
make extract
```

That dumps the original tray assets into:

- `resources/original/img/tray`
- `resources/original/manifest.txt`

The public repo intentionally does not commit the exact extracted vendor tray
PNGs. If you need to regenerate assets from the originals, run `make extract`
locally first.
