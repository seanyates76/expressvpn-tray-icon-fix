# Arch Packaging Notes

This directory currently contains a local-tree `PKGBUILD` for
`expressvpn-tray-icon-fix`.

Upstream repo:

- `https://github.com/seanyates76/expressvpn-tray-icon-fix`

## Current Use

Build from the checked-out working tree:

```bash
makepkg -fsi
```

Or from the repo root:

```bash
make package-arch-install
```

This package installs:

- `/usr/bin/expressvpn-tray-icon-fix`
- `/usr/bin/expressvpn-tray-icon-fix-integrate`
- `/usr/lib/expressvpn-tray-icon-fix/...`
- `/usr/share/applications/expressvpn-tray-icon-fix.desktop`
- manual pages and docs

The install script attempts to enable the mod immediately for the invoking user
by creating managed user-local overrides for the standard ExpressVPN launcher and
autostart entry.

## Current Limitation

`PKGBUILD` is intentionally written for local-tree packaging. It does not yet
download sources from a public upstream URL.

That means these fields still need to be replaced before publishing to AUR:

- `source`
- `sha256sums`

## AUR Conversion Checklist

1. Publish the project to a real upstream repo or release tarball URL.
2. Update `url` in `PKGBUILD`.
3. Replace the empty `source=()` with the upstream archive or VCS source.
4. Replace `sha256sums=()` with real checksums, or use `SKIP` only for a VCS package.
5. Ensure `build()` and `package()` operate from the extracted source tree instead of the local working tree.
6. Regenerate `.SRCINFO`:

```bash
makepkg --printsrcinfo > .SRCINFO
```

7. Test again with:

```bash
makepkg -f --nodeps
```

## Suggested Packaging Direction

For AUR, the cleanest approach is probably one of:

- a release package that builds from a source tarball
- a `-git` package if the project is expected to move quickly

The current local-tree package is a good base for either one, but it still needs
a real upstream source location before publication.
