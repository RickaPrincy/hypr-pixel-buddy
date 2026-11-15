#!/usr/bin/env bash
# Relance automatiquement les instances Quickshell (barre/fond "ii" et "buddy")
# si elles crashent, pour ne plus avoir à relancer Hyprland à la main.

LOG="$HOME/.cache/hypr-pixel-buddy-watchdog.log"
INTERVAL=5

# Une seule instance du watchdog (sinon plusieurs relancent buddy en même temps -> doublons)
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/hypr-pixel-buddy-watchdog.lock"
flock -n 9 || exit 0

log() { printf '%s %s\n' "$(date '+%F %T')" "$1" >> "$LOG"; }

# Une instance peut se relancer toute seule et perdre ses arguments (elle apparaît alors
# comme "/usr/bin/quickshell"), donc on se fie au chemin de config listé par quickshell.
running() { qs list --all 2>/dev/null | grep -q "Config path: $HOME/.config/quickshell/$1/shell.qml"; }

# Relance buddy de force (kill + start) : après une mise en veille le process peut
# rester vivant mais sans fenêtre, donc "running" ne suffit pas à le détecter.
# Verrou + on tue TOUTES les instances de buddy avant d'en lancer une seule (jamais de doublon).
restart_buddy() {
    (
        flock 8
        log "$1 -> redémarrage de buddy"
        qs list --all 2>/dev/null | awk -v c="$HOME/.config/quickshell/buddy/shell.qml" '
            /Process ID:/ { pid = $3 }
            $0 ~ "Config path: " c { print pid }' | xargs -r kill 2>/dev/null
        sleep 1
        nohup qs -c buddy -d >/dev/null 2>&1 &
        disown
    ) 8>"${XDG_RUNTIME_DIR:-/tmp}/hypr-pixel-buddy-restart.lock"
}

# Vrai si buddy est dessous le fond de ii (même couche "bottom") : il tourne mais est invisible.
# Hyprland liste les layers dans l'ordre d'empilement, le dernier est au-dessus.
buddy_hidden() {
    hyprctl layers 2>/dev/null | awk '
        /^Monitor/ { bud = 0; bg = 0; n = 0 }
        /namespace: quickshell:buddy/      { bud = ++n }
        /namespace: quickshell:background/ { bg = ++n }
        bud && bg && bud < bg { hidden = 1 }
        END { exit hidden ? 0 : 1 }'
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
        # ii recrée son fond par-dessus buddy : on relance buddy après lui
        restart_buddy "ii relancé"
    elif running buddy && buddy_hidden; then
        restart_buddy "buddy caché sous le fond de ii"
    fi

    if ! running buddy; then
        log "buddy a disparu, relance..."
        nohup qs -c buddy -d >/dev/null 2>&1 &
        disown
        sleep 5
    fi

    sleep "$INTERVAL"
done
