# ExpressVPN Tray Icon Fix

Package name: `expressvpn-tray-icon-fix`

GitHub:

- `https://github.com/seanyates76/expressvpn-tray-icon-fix`

This project is a Linux mod for ExpressVPN's tray icons. It replaces the embedded
Qt tray resources with improved themed assets and keeps the tray icon switching
live with the current light/dark system theme.

For end users, the package path is the primary path now. The local `make install`
flow is only for development.

## Current Runtime Model

- the preload hook follows the system theme and live-switches the tray icon
- live tray refresh is file-backed, not just `:/img/tray/...` resource-backed
- the runtime ships both style options:
  - `colored`
  - `monochrome`

Canonical asset sets live under:

- `resources/themed/img/tray-dark-colored`
- `resources/themed/img/tray-dark-monochrome`
- `resources/themed/img/tray-light-colored`
- `resources/themed/img/tray-light-monochrome`

## Standard Arch Install

For a normal package-manager install from this working tree:

```bash
cd packaging/arch
makepkg -fsi
```

That builds `expressvpn-tray-icon-fix` and installs it with `pacman`.

When installed through `sudo pacman`, the package also attempts to enable
itself immediately for the invoking user by creating managed user-local
overrides for:

- `~/.local/share/applications/expressvpn.desktop`
- `~/.config/autostart/expressvpn-client.desktop`

So after install, the normal `ExpressVPN` launcher path already uses the mod.
The packaged `expressvpn-tray-icon-fix.desktop` entry is hidden from menus so
search results stay under `ExpressVPN`.

If you already built the package archive, install it with:

```bash
sudo pacman -U ./expressvpn-tray-icon-fix-0.1.0-1-x86_64.pkg.tar.zst
```

The installed command is:

- `expressvpn-tray-icon-fix`

The integration helper is:

- `expressvpn-tray-icon-fix-integrate`

Manual pages:

- `man expressvpn-tray-icon-fix`
- `man expressvpn-tray-icon-fix-integrate`

## Local Dev Install

The custom `make install` flow is only for working-tree development and testing.

```bash
make install STYLE=colored
```

Or:

```bash
make install STYLE=monochrome
```

Remove the local dev install with:

```bash
make uninstall
```

## Package Runtime Staging

Build the package runtime layout locally:

```bash
make stage-package-runtime
```

That stages a package-style runtime tree at:

- `build/package-runtime/expressvpn-tray-icon-fix`

The staged runtime includes:

- `lib/libexpressvpn-tray-override.so`
- `styles/colored/...`
- `styles/monochrome/...`

## Arch Package

An Arch-style package skeleton lives in:

- `packaging/arch/PKGBUILD`
- `packaging/arch/README.md`

For local package builds from this working tree:

```bash
cd packaging/arch
makepkg -f
```

The package installs:

- `/usr/bin/expressvpn-tray-icon-fix`
- `/usr/share/applications/expressvpn-tray-icon-fix.desktop`
- `/usr/lib/expressvpn-tray-icon-fix/...`

So the package manager can install it directly without a separate post-install
"copy this into ~/.local" step.

`.SRCINFO` is included under:

- `packaging/arch/.SRCINFO`

The current `PKGBUILD` is suitable for local Arch packaging from this tree. The
remaining AUR work is converting it from a local-tree package to a package that
builds from real GitHub sources.

That upstream repo URL is now reserved here:

- `https://github.com/seanyates76/expressvpn-tray-icon-fix`

The remaining AUR work is switching the package from local-tree build inputs to
real GitHub sources or a `-git` source package.

There are helper targets at the repo root for this:

```bash
make package-arch
make package-arch-install
make srcinfo
```

## Style Selection

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

Or launch with:

```bash
EXPRESSVPN_TRAY_ICON_FIX_STYLE=monochrome expressvpn-tray-icon-fix
```

By default, the packaged launcher backgrounds the GUI app when run from a
terminal. To keep it attached for debugging:

```bash
expressvpn-tray-icon-fix --foreground
```

Short help is available with:

```bash
expressvpn-tray-icon-fix -h
expressvpn-tray-icon-fix-integrate -h
```

## Asset Workflow

Refresh the themed asset sets with:

```bash
./scripts/build_tray_variants.sh
```

The dark and light tray resource names used by ExpressVPN are documented in:

- `docs/resource-map.md`

## Extraction

The embedded tray PNGs can still be re-extracted from the ExpressVPN client with:

```bash
make extract
```

That dumps the original tray assets into:

- `resources/original/img/tray`
- `resources/original/manifest.txt`

The public repo intentionally does not commit the exact extracted vendor tray
PNGs. If you need to regenerate assets from the originals, run `make extract`
locally first.
