# Security

`expressvpn-tray-icon-fix` is a user-space tray icon mod for the ExpressVPN
Linux GUI. This is the first public release.

For the detailed behavior and trust boundary, see `docs/TRANSPARENCY.md`.

Security boundary:

- does not modify `/opt/expressvpn`
- does not inspect or route VPN traffic
- runs in user space through a launcher and preload override

## Reporting An Issue

Open an issue in the repository.

Include:

- ExpressVPN version or build channel
- distro and version
- desktop and session type
- reproduction steps
