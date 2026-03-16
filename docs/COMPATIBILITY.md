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
| Stable build `5.1.0+12141` | Arch Linux | KDE Plasma | Wayland | Arch package | Tested | Tested | Tested | Public stable installer `expressvpn-linux-x86_64-5.1.0.12141_release` |
| Beta build `14.0.0-beta+12559` | Arch Linux | KDE Plasma | Wayland | Arch package | Tested | Tested | Tested | Public beta installer `expressvpn-linux-x86_64-14.0.0.12559_beta` |

Note: on the current tested builds, the app still runs through its
X11 compatibility path in a Wayland session. Native Wayland runtime is not
currently verified.

Note: the tested stable and beta installers currently expose the same embedded
tray resource set and the same vendor X11 compatibility path.

## Not Yet Verified

| ExpressVPN build | Distro | Desktop | Session | Install path | Startup | Tray override | Live theme switch | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Stable build `5.1.0+12141` | Arch Linux | KDE Plasma | X11 | Arch package | Untested | Untested | Untested | Desktop session not yet tested directly |
| Beta build `14.0.0-beta+12559` | Arch Linux | KDE Plasma | X11 | Arch package | Untested | Untested | Untested | Desktop session not yet tested directly |
| Stable build `5.1.0+12141` | Debian-family | KDE Plasma | X11 | manual runtime | Untested | Untested | Untested | Path assumptions may need adjustment |
| Stable build `5.1.0+12141` | Fedora-family | KDE Plasma | X11 | manual runtime | Untested | Untested | Untested | Path assumptions may need adjustment |
| Stable build `5.1.0+12141` | Any distro | GNOME | X11/Wayland | manual runtime | Untested | Untested | Untested | Theme detection is file-based, not GNOME-shell-tested |
| Beta build `14.0.0-beta+12559` | Debian-family | KDE Plasma | X11 | manual runtime | Untested | Untested | Untested | Path assumptions may need adjustment |
| Beta build `14.0.0-beta+12559` | Fedora-family | KDE Plasma | X11 | manual runtime | Untested | Untested | Untested | Path assumptions may need adjustment |
| Beta build `14.0.0-beta+12559` | Any distro | GNOME | X11/Wayland | manual runtime | Untested | Untested | Untested | Theme detection is file-based, not GNOME-shell-tested |

## Current Assumptions

These are the main compatibility assumptions in the current runtime:

- ExpressVPN client path is `/opt/expressvpn/bin/expressvpn-client`
- Tray implementation still uses `QSystemTrayIcon`
- Tray state/resource naming still matches the current known states
- System theme can be inferred from KDE/GTK config files
- the packaged launcher explicitly sets `XDG_SESSION_TYPE=X11`
- current Wayland-session testing still uses the app's X11 compatibility path
- native Wayland runtime remains unverified

If any of those change, compatibility may drop from `Tested` to `Partial` or `Broken`.

## Recommended Next Tests

1. ExpressVPN stable build on Arch KDE X11
2. ExpressVPN beta build on Arch KDE X11
3. One Debian-family VM with KDE
4. One Fedora-family VM with KDE

## Reporting Results

When adding a new test result, record:

- ExpressVPN version and installer/build identifier
- distro and version
- desktop and session type
- install method used
- whether startup works
- whether the tray icon is overridden
- whether live light/dark switching works
- any path or theme-detection quirks
