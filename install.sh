#!/usr/bin/env bash
# Installe hypr-pixel-buddy sur une config Hyprland + illogical-impulse
set -euo pipefail
cd "$(dirname "$0")"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
II="$CFG/quickshell/ii"

echo ":: buddy (Quickshell)"
mkdir -p "$CFG/quickshell"
rm -rf "$CFG/quickshell/buddy"
cp -r quickshell/buddy "$CFG/quickshell/buddy"

echo ":: Hyprland custom"
mkdir -p "$CFG/hypr/custom/scripts/wallpaper"
for f in keybinds.lua execs.lua general.lua scripts/screenshot.sh scripts/wallpaper/make_hello_world.py; do
    dst="$CFG/hypr/custom/$f"
    if [[ -f "$dst" ]] && ! cmp -s "hypr/custom/$f" "$dst"; then cp "$dst" "$dst.bak"; fi
    cp "hypr/custom/$f" "$dst"
done
chmod +x "$CFG/hypr/custom/scripts/screenshot.sh"

echo ":: wallpaper"
mkdir -p "$HOME/Pictures/Wallpapers"
cp wallpapers/* "$HOME/Pictures/Wallpapers/"

if [[ -d "$II" ]]; then
    echo ":: patch illogical-impulse"
    W="$II/modules/ii/background/widgets/AbstractBackgroundWidget.qml"
    if grep -q "\[buddy\]" "$W"; then
        echo "   already applied"
    else
        cp -n "$W" "$W.orig-buddy"
        patch -p1 -d "$II" < patches/ii-clock-buddy.patch
    fi
    "$II/scripts/colors/switchwall.sh" --image "$HOME/Pictures/Wallpapers/pixel-world.png" >/dev/null 2>&1 || true
    C="$CFG/illogical-impulse/config.json"
    if [[ -f "$C" ]]; then
        jq '.background.widgets.clock.placementStrategy = "free"' "$C" > "$C.tmp" && mv "$C.tmp" "$C"
    fi
else
    echo "!! illogical-impulse not found ($II): skipping patch and wallpaper"
fi

echo ":: start buddy"
qs -c buddy kill >/dev/null 2>&1 || true
qs -c buddy -d >/dev/null 2>&1 || true
hyprctl reload >/dev/null 2>&1 || true
echo "done ✔"
