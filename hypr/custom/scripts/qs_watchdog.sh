#!/usr/bin/env bash
# Relance automatiquement les instances Quickshell (barre/fond "ii" et "buddy")
# si elles crashent, pour ne plus avoir à relancer Hyprland à la main.

LOG="$HOME/.cache/hypr-pixel-buddy-watchdog.log"
INTERVAL=5

log() { printf '%s %s\n' "$(date '+%F %T')" "$1" >> "$LOG"; }

# Une instance peut se relancer toute seule et perdre ses arguments (elle apparaît alors
# comme "/usr/bin/quickshell"), donc on se fie au chemin de config listé par quickshell.
running() { qs list --all 2>/dev/null | grep -q "Config path: $HOME/.config/quickshell/$1/shell.qml"; }

# Relance buddy de force (kill + start) : après une mise en veille le process peut
# rester vivant mais sans fenêtre, donc "running" ne suffit pas à le détecter.
restart_buddy() {
    log "$1 -> redémarrage de buddy"
    qs -c buddy kill >/dev/null 2>&1
    sleep 1
    nohup qs -c buddy -d >/dev/null 2>&1 &
    disown
}

# Sortie de veille : logind émet PrepareForSleep(false) au réveil.
(
    gdbus monitor --system --dest org.freedesktop.login1 2>/dev/null | while read -r line; do
        case "$line" in
            *PrepareForSleep*false*)
                sleep 3  # laisse les écrans se rallumer
                restart_buddy "sortie de veille (logind)"
                ;;
        esac
    done
) &

# Laisse le temps à la séquence de démarrage normale de finir (ii, buddy, etc.)
sleep 15

last=$(date +%s)
while true; do
    # Filet de sécurité : si l'horloge a sauté (veille/hibernation), on relance buddy
    now=$(date +%s)
    if (( now - last > INTERVAL * 4 )); then
        sleep 3
        restart_buddy "saut d'horloge de $((now - last))s (veille)"
    fi
    last=$now

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
