# Compatibility

This project is currently:

- Arch package first
- Linux runtime mod
- compatibility tracked by tested combinations only

## Status Legend

- `Tested`
- `Partial`
- `Untested`
- `Broken`

Entries marked `Untested` are not currently claimed as supported.

## Verified So Far

| ExpressVPN build | Distro | Desktop | Session | Install path | Startup | Tray override | Live theme switch | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Current development beta build | Arch Linux | KDE Plasma | X11 | Arch package | Tested | Tested | Tested | Current main development target |

## Not Yet Verified

| ExpressVPN build | Distro | Desktop | Session | Install path | Startup | Tray override | Live theme switch | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Stable build | Arch Linux | KDE Plasma | X11 | Arch package | Untested | Untested | Untested | Highest priority next test |
| Beta build | Arch Linux | KDE Plasma | Wayland | Arch package | Untested | Untested | Untested | Session behavior may differ |
| Stable build | Arch Linux | KDE Plasma | Wayland | Arch package | Untested | Untested | Untested | Session + build both unverified |
| Stable build | Debian-family | KDE Plasma | X11 | manual runtime | Untested | Untested | Untested | Path assumptions may need adjustment |
| Stable build | Fedora-family | KDE Plasma | X11 | manual runtime | Untested | Untested | Untested | Path assumptions may need adjustment |
| Stable build | Any distro | GNOME | X11/Wayland | manual runtime | Untested | Untested | Untested | Theme detection is file-based, not GNOME-shell-tested |

## Current Assumptions

These are the main compatibility assumptions in the current runtime:

- ExpressVPN client path is `/opt/expressvpn/bin/expressvpn-client`
- Tray implementation still uses `QSystemTrayIcon`
- Tray state/resource naming still matches the current known states
- System theme can be inferred from KDE/GTK config files
- the packaged launcher explicitly sets `XDG_SESSION_TYPE=X11`
- the current runtime path therefore expects X11 behavior
- Wayland has not yet been verified for this release

If any of those change, compatibility may drop from `Tested` to `Partial` or `Broken`.

## Recommended Next Tests

1. ExpressVPN stable build on Arch KDE X11
2. ExpressVPN stable build on Arch KDE Wayland
3. One Debian-family VM with KDE
4. One Fedora-family VM with KDE

## Reporting Results

When adding a new test result, record:

- ExpressVPN build channel and version
- distro and version
- desktop and session type
- install method used
- whether startup works
- whether the tray icon is overridden
- whether live light/dark switching works
- any path or theme-detection quirks
