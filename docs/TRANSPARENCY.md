# Transparency

`expressvpn-tray-icon-fix` is an unofficial user-side mod for the ExpressVPN
Linux GUI.

It is a small tray-icon customization layer, not a VPN engine, proxy, or daemon
replacement.

The practical reason to trust it, if you do, should be that the install path
and runtime behavior are narrow enough to inspect. The important question is
not "does this sound trustworthy," but "can I verify what it installs,
launches, reads, and writes."

## What It Does

- installs a wrapper launcher and integration helper
- installs a package-owned desktop entry at
  `/usr/share/applications/expressvpn-tray-icon-fix.desktop`
- injects a preload library into the ExpressVPN GUI process at launch
- replaces the tray icon art with improved light/dark assets
- follows the current system light/dark theme and updates the tray icon live

## What It Does Not Do

- patch or overwrite `/opt/expressvpn` vendor files
- replace the ExpressVPN daemon or CLI
- inspect, route, log, or modify VPN traffic
- transmit analytics or phone-home data of its own

## What It Reads

- system theme config files such as KDE, GTK, or XSettings theme settings
- a small local style preference file at
  `~/.config/expressvpn-tray-icon-fix/style`
- installed ExpressVPN GUI binary metadata used to scope the runtime hook to
  the expected client build

## What It Writes

- a package-owned desktop entry under `/usr/share/applications`
- user integration files under standard XDG paths such as
  `~/.local/share/applications/expressvpn.desktop` and
  `~/.config/autostart/expressvpn-client.desktop`
- local runtime assets and the preload library under the package runtime root
- the optional style preference file mentioned above

## How To Verify It

If you are deciding whether to trust this project, review the same places that
control the real behavior:

- `packaging/arch/PKGBUILD`
- `packaging/arch/expressvpn-tray-icon-fix.install`
- `packaging/bin/expressvpn-tray-icon-fix`
- `tools/src/resource_override.cpp`
- `docs/COMPATIBILITY.md`

Useful sanity checks:

- confirm the package does not overwrite files under `/opt/expressvpn`
- confirm the launcher and integration helper only write under expected XDG
  paths
- confirm the runtime behavior matches `README.md`
- prefer releases that can be traced back to tagged source

If you want AI help reviewing the repo, use it as a structured code-review
assistant, not as proof. A good prompt is:

```text
Audit this repository as an unofficial Linux tray-icon mod for ExpressVPN.

Focus on:
- what files it installs
- what it executes at runtime
- what user or system files it reads and writes
- whether it modifies vendor files under /opt/expressvpn
- whether it appears to inspect network traffic or sensitive user data
- whether the package and launcher behavior match the README
- what risks, blind spots, or unsupported assumptions remain

Do not give generic reassurance. Point to exact files and call out anything you
cannot verify from the source alone.
```

## Runtime Boundary

- the runtime override is applied at launch time
- vendor files under `/opt/expressvpn` stay untouched
- live tray updates use file-backed assets and system theme detection
- the current packaged launcher runs the GUI under `XDG_SESSION_TYPE=X11`
