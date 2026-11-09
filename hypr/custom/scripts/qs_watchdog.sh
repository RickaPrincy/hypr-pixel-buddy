#!/usr/bin/env bash
# Relance automatiquement les instances Quickshell (barre/fond "ii" et "buddy")
# si elles crashent, pour ne plus avoir à relancer Hyprland à la main.

LOG="$HOME/.cache/hypr-pixel-buddy-watchdog.log"
INTERVAL=5

log() { printf '%s %s\n' "$(date '+%F %T')" "$1" >> "$LOG"; }

# Une instance peut se relancer toute seule et perdre ses arguments (elle apparaît alors
# comme "/usr/bin/quickshell"), donc on se fie au chemin de config listé par quickshell.
running() { qs list --all 2>/dev/null | grep -q "Config path: $HOME/.config/quickshell/$1/shell.qml"; }

# Laisse le temps à la séquence de démarrage normale de finir (ii, buddy, etc.)
sleep 15

while true; do
    if ! running ii; then
        log "ii (barre/fond) ne tourne plus, relance..."
        nohup qs -c ii >/dev/null 2>&1 &
        disown
        sleep 5
    fi

    if ! running buddy; then
        log "buddy a disparu, relance..."
        nohup qs -c buddy -d >/dev/null 2>&1 &
        disown
        sleep 5
    fi

    sleep "$INTERVAL"
done
