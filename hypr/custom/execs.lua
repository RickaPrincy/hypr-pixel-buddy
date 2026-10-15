hl.on("hyprland.start", function ()
    -- Petit compagnon de bureau (lancé après ii pour être au-dessus de son fond)
    hl.exec_cmd("sleep 2 && qs -c buddy -d")

    -- Surveille ii et buddy, les relance tout seul s'ils crashent
    -- (plus besoin de relancer Hyprland à la main)
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/qs_watchdog.sh")
end)
