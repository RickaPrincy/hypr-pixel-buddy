#!/usr/bin/env bash
# Capture d'écran : sauvegarde dans ~/Pictures/Screenshots + copie dans le presse-papiers
# Usage : screenshot.sh [region|full|edit]
mode="${1:-region}"
dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
mkdir -p "$dir"
file="$dir/Screenshot_$(date '+%Y-%m-%d_%H.%M.%S').png"

case "$mode" in
    full)
        mon="$(hyprctl activeworkspace -j | jq -r '.monitor')"
        grim -o "$mon" "$file" || exit 1
        ;;
    region|edit)
        pidof slurp >/dev/null && exit 0
        geom="$(slurp -d)" || exit 0
        grim -g "$geom" "$file" || exit 1
        ;;
esac

if [[ "$mode" == "edit" ]]; then
    swappy -f "$file" -o "$file"
fi

wl-copy < "$file"

action=$(notify-send -a "Capture d'écran" -i "$file" \
    -A "open=Ouvrir" -A "edit=Annoter" -A "folder=Dossier" \
    "Capture enregistrée" "$(basename "$file")\n(copiée dans le presse-papiers)")
case "$action" in
    open) xdg-open "$file" ;;
    edit) swappy -f "$file" -o "$file" && wl-copy < "$file" ;;
    folder) xdg-open "$dir" ;;
esac
