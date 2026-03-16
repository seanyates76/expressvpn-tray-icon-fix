# Contributing

Thanks for contributing to `expressvpn-tray-icon-fix`.

## Priorities

- keep the packaged install path working first
- keep the canonical tray assets clean and correctly named
- keep live light/dark switching reliable
- keep Arch packaging and docs in sync

## Local Checks

Before opening a pull request, run:

```bash
make package-arch
make srcinfo
```

If you touched shell scripts, also run:

```bash
bash -n packaging/bin/expressvpn-tray-icon-fix
bash -n packaging/bin/expressvpn-tray-icon-fix-integrate
sh -n packaging/arch/expressvpn-tray-icon-fix.install
bash -n scripts/*.sh
```

## Packaging Rules

- update `packaging/arch/.SRCINFO` whenever `packaging/arch/PKGBUILD` changes
- keep the package name as `expressvpn-tray-icon-fix`
- preserve the current install behavior: install -> standard `ExpressVPN` launcher uses the mod

## Asset Rules

- preserve the original ExpressVPN tray filenames
- treat `resources/themed/img/tray-*` as canonical shipped assets
- treat generator scripts as helpers, not the product definition

## Pull Requests

Please keep pull requests focused. Small packaging, asset, or runtime changes are
much easier to review than mixed refactors.
