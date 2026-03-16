#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

style="${1:-colored}"
prefix="${2:-$HOME/.local}"

case "$style" in
  colored|monochrome) ;;
  *)
    echo "Invalid style: $style" >&2
    echo "Expected: colored or monochrome" >&2
    exit 1
    ;;
esac

themed_dir="$project_dir/resources/themed/img"
case "$style" in
  colored)
    selected_dark_dir="$themed_dir/tray-dark-colored"
    selected_light_dir="$themed_dir/tray-light-colored"
    ;;
  monochrome)
    selected_dark_dir="$themed_dir/tray-dark-monochrome"
    selected_light_dir="$themed_dir/tray-light-monochrome"
    ;;
esac

share_dir="$prefix/share/expressvpn-tray-override"
bin_dir="$prefix/bin"
applications_dir="$prefix/share/applications"
assets_root="$share_dir/assets"
assets_dark_dir="$assets_root/dark"
assets_light_dir="$assets_root/light"
wrapper_path="$bin_dir/expressvpn-client-tray-override"
desktop_path="$applications_dir/expressvpn.desktop"
preload_path="$share_dir/libexpressvpn-tray-override.so"
rcc_path="$share_dir/override.rcc"
rcc_dark_path="$share_dir/override-dark.rcc"
rcc_light_path="$share_dir/override-light.rcc"
style_path="$share_dir/style.txt"
app_path="/opt/expressvpn/bin/expressvpn-client"

mkdir -p "$share_dir" "$bin_dir" "$applications_dir" "$assets_dark_dir" "$assets_light_dir"

"$project_dir/scripts/build_tray_variants.sh"
make -C "$project_dir" override-preload >/dev/null

tmp_rcc="$project_dir/build/install/$style/override.rcc"
tmp_rcc_dark="$project_dir/build/install/$style/override-dark.rcc"
tmp_rcc_light="$project_dir/build/install/$style/override-light.rcc"
"$project_dir/scripts/build-override-rcc.sh" "$style" "$tmp_rcc" combined >/dev/null
"$project_dir/scripts/build-override-rcc.sh" "$style" "$tmp_rcc_dark" locked-dark >/dev/null
"$project_dir/scripts/build-override-rcc.sh" "$style" "$tmp_rcc_light" locked-light >/dev/null

install -m 0644 "$selected_dark_dir"/square-dark-no-outline-margins-*.png "$assets_dark_dir"/
install -m 0644 "$selected_light_dir"/square-light-no-outline-margins-*.png "$assets_light_dir"/

install -m 0755 "$project_dir/build/libexpressvpn-tray-override.so" "$preload_path"
install -m 0644 "$tmp_rcc" "$rcc_path"
install -m 0644 "$tmp_rcc_dark" "$rcc_dark_path"
install -m 0644 "$tmp_rcc_light" "$rcc_light_path"
printf '%s\n' "$style" > "$style_path"

app_size="$(stat -c '%s' "$app_path")"
app_mtime="$(stat -c '%Y' "$app_path")"

{
  printf '#!/usr/bin/env bash\n'
  printf 'set -euo pipefail\n'
  printf 'detect_system_icon_set() {\n'
  printf '  local config_home system_theme_path path\n'
  printf '  config_home="${XDG_CONFIG_HOME:-$HOME/.config}"\n'
  printf '  system_theme_path="${EXPRESSVPN_TRAY_SYSTEM_THEME_FILE:-}"\n'
  printf '  for path in "$system_theme_path" "$config_home/xsettingsd/xsettingsd.conf" "$config_home/kdeglobals" "$config_home/gtk-3.0/settings.ini" "$config_home/gtk-4.0/settings.ini"; do\n'
  printf '    [[ -n "$path" && -f "$path" ]] || continue\n'
  printf '    if grep -qiE '\''gtk-application-prefer-dark-theme *= *true|^(Net/ThemeName|Net/IconThemeName) .*dark|^gtk-icon-theme-name=.*dark|^(gtk-theme-name|LookAndFeelPackage|ColorScheme)=.*dark'\'' "$path"; then\n'
  printf '      printf '\''dark\\n'\''\n'
  printf '      return 0\n'
  printf '    fi\n'
  printf '    if grep -qiE '\''gtk-application-prefer-dark-theme *= *false|^(Net/ThemeName|Net/IconThemeName) \".*breeze\"|^gtk-icon-theme-name=breeze$|^(LookAndFeelPackage|ColorScheme)=.*light'\'' "$path"; then\n'
  printf '      printf '\''light\\n'\''\n'
  printf '      return 0\n'
  printf '    fi\n'
  printf '  done\n'
  printf '  printf '\''light\\n'\''\n'
  printf '}\n'
  printf 'settings_path="${XDG_CONFIG_HOME:-$HOME/.config}/expressvpn/clientsettings.json"\n'
  printf 'system_theme_path="${EXPRESSVPN_TRAY_SYSTEM_THEME_FILE:-}"\n'
  printf 'system_icon_set="$(detect_system_icon_set)"\n'
  printf 'if [[ -f "$settings_path" ]]; then\n'
  printf '  tmp_settings="$(mktemp)"\n'
  printf '  sed -E "s/\\"iconSet\\":\\"[^\\"]+\\"/\\"iconSet\\":\\"$system_icon_set\\"/" "$settings_path" > "$tmp_settings"\n'
  printf '  mv "$tmp_settings" "$settings_path"\n'
  printf 'fi\n'
  printf 'export TRAY_OVERRIDE_RCC=%q\n' "$rcc_path"
  printf 'export TRAY_OVERRIDE_RCC_DARK=%q\n' "$rcc_dark_path"
  printf 'export TRAY_OVERRIDE_RCC_LIGHT=%q\n' "$rcc_light_path"
  printf 'export TRAY_OVERRIDE_ASSET_ROOT=%q\n' "$assets_root"
  printf 'export EXPRESSVPN_TRAY_SYNC_ICONSET=1\n'
  printf 'export EXPRESSVPN_TRAY_SYNC_APP_SIZE=%q\n' "$app_size"
  printf 'export EXPRESSVPN_TRAY_SYNC_APP_MTIME=%q\n' "$app_mtime"
  printf 'if [[ -n "$system_theme_path" ]]; then\n'
  printf '  export EXPRESSVPN_TRAY_SYSTEM_THEME_FILE="$system_theme_path"\n'
  printf 'fi\n'
  printf 'export LD_PRELOAD=%q"${LD_PRELOAD:+:${LD_PRELOAD}}"\n' "$preload_path"
  printf 'exec -a %q env -u SESSION_MANAGER XDG_SESSION_TYPE=X11 %q "$@"\n' "$wrapper_path" "$app_path"
} > "$wrapper_path"
chmod 0755 "$wrapper_path"

{
  printf '[Desktop Entry]\n'
  printf 'Type=Application\n'
  printf 'Name=ExpressVPN\n'
  printf 'Comment=ExpressVPN VPN client with tray override\n'
  printf 'Path=/opt/expressvpn/bin/\n'
  printf 'TryExec=%q\n' "$app_path"
  printf 'Exec=%q %%u\n' "$wrapper_path"
  printf 'Icon=expressvpn\n'
  printf 'Terminal=false\n'
  printf 'Categories=Network\n'
  printf 'StartupWMClass=expressvpn-client\n'
  printf 'MimeType=x-scheme-handler/expressvpn\n'
} > "$desktop_path"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
  kbuildsycoca5 >/dev/null 2>&1 || true
fi

echo "Installed ExpressVPN tray override."
echo "  style:   $style"
echo "  prefix:  $prefix"
echo "  wrapper: $wrapper_path"
echo "  desktop: $desktop_path"
