# Release Notes For Maintainers

This file is for maintainers preparing public source or release artifacts.

Target upstream repo:

- `https://github.com/seanyates76/expressvpn-tray-icon-fix`

## Current State

The current `packaging/arch/PKGBUILD` is still a local-tree package. That is
good for development, local testing, and first public Arch release artifacts,
but not enough for a proper AUR release package.

## Release Package Path

When the repo is public and you are ready to publish the first public release:

1. Push the current tree to GitHub.
2. Create a tag such as `v0.1.0`.
3. Let GitHub Actions build and attach the Arch package artifact to the release.
4. Decide whether the AUR package should build from:
   - a GitHub release tarball, or
   - a `-git` source package
5. Update `packaging/arch/PKGBUILD`:
   - set `url` to the real GitHub repo
   - replace `source=()` with the release tarball or VCS source
   - replace `sha256sums=()` with real checksums, or `SKIP` for a VCS package
   - make `build()` and `package()` operate from the extracted source tree
6. Regenerate `.SRCINFO`:

```bash
make srcinfo
```

7. Rebuild and test:

```bash
make package-arch
```

## Suggested GitHub Release Tarball Pattern

For a tagged release, the source URL will usually look like:

```text
https://github.com/seanyates76/expressvpn-tray-icon-fix/archive/refs/tags/v${pkgver}.tar.gz
```

## Suggested First Public Tags

- `v0.1.0` for the first public packageable state
- `v0.1.1` and later for packaging or asset fixes
