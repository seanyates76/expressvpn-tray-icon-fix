# Variant Options

## Canonical Asset Sets

- `resources/themed/img/tray-dark-colored`
  - current cleaned dark theme with colored status indicators
- `resources/themed/img/tray-dark-monochrome`
  - dark theme with all status indicators rendered in white
- `resources/themed/img/tray-light-colored`
  - light theme with colored status indicators
- `resources/themed/img/tray-light-monochrome`
  - light theme with monochrome white status indicators

## Suggested Prompt Labels

- `Colored status indicators`
- `Monochrome status indicators`

## Current Mapping

- `Colored status indicators`
  - dark theme -> `tray-dark-colored`
  - light theme -> `tray-light-colored`
- `Monochrome status indicators`
  - dark theme -> `tray-dark-monochrome`
  - light theme -> `tray-light-monochrome`

## Build Workflow

Run:

```bash
./scripts/build_tray_variants.sh
```

That preserves the current cleaned dark-colored set as the canonical dark-colored directory, then regenerates:

- `tray-dark-monochrome`
- `tray-light-colored`
- `tray-light-monochrome`

## Install Mapping

- `make install STYLE=colored`
  - dark theme -> `tray-dark-colored`
  - light theme -> `tray-light-colored`
- `make install STYLE=monochrome`
  - dark theme -> `tray-dark-monochrome`
  - light theme -> `tray-light-monochrome`

## Packaged Mapping

Package name:

- `expressvpn-tray-icon-fix`

Packaged launcher:

- `expressvpn-tray-icon-fix`

Packaged desktop entry:

- `expressvpn-tray-icon-fix.desktop`

Packaged default:

- `colored`

Optional packaged user config:

- `~/.config/expressvpn-tray-icon-fix/style`

Accepted values:

- `colored`
- `monochrome`
