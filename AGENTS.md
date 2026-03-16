# ExpressVPN Tray Icon Fix

## Mission

Maintain a mature Linux tray-icon mod for ExpressVPN that is practical to ship,
package, and test.

The product is:

- improved tray icon assets
- a runtime preload hook that keeps the tray synced with system light/dark theme
- a package/install path that makes the standard ExpressVPN launcher use the mod

## Current Ground Truth

- ExpressVPN's tray icons originate from embedded Qt resources inside `/opt/expressvpn/bin/expressvpn-client`.
- Live tray switching is currently implemented by a preload hook in `tools/src/resource_override.cpp`.
- Live refresh is file-backed from installed PNG assets, not only `:/img/tray/...` resources.
- The packaged project name is `expressvpn-tray-icon-fix`.
- The packaged launcher is `expressvpn-tray-icon-fix`.
- The package also ships `expressvpn-tray-icon-fix-integrate` to manage per-user desktop/autostart overrides.

## Canonical Asset Sets

- `resources/themed/img/tray-dark-colored`
- `resources/themed/img/tray-dark-monochrome`
- `resources/themed/img/tray-light-colored`
- `resources/themed/img/tray-light-monochrome`

Treat those directories as the real product assets. Generation scripts are
helpers, not the project definition.

Exact extracted vendor tray assets are local regeneration inputs only. Do not
reintroduce them into the public repo casually.

## Working Priorities

1. Keep the packaged install path working.
2. Keep the tray assets clean and easy to update.
3. Keep live light/dark switching reliable.
4. Keep packaging and docs straightforward for Arch/AUR publication.

## Packaging Reality

- `packaging/arch/PKGBUILD` is the current local-tree Arch package.
- `packaging/arch/.SRCINFO` must stay in sync with `PKGBUILD`.
- `packaging/arch/README.md` is the publication handoff for moving from local-tree packaging to AUR packaging.
- The package should feel like install -> it works. Avoid adding setup steps unless they are optional recovery paths.

## Guardrails

- Do not patch or overwrite files under `/opt/expressvpn` unless the user explicitly asks.
- Prefer packaged or user-local integration over touching vendor files.
- Preserve the canonical themed asset directories and correct Qt resource filenames.
- Avoid drifting back into launcher-icon/theme-override detours unless the user explicitly redirects there.

## Useful Habits

- Verify packaging changes with `makepkg` after editing Arch files.
- Keep `README.md` focused on the packaged user path first, dev path second.
