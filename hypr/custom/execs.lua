hl.on("hyprland.start", function ()
    -- Petit compagnon de bureau (lancé après ii pour être au-dessus de son fond)
    hl.exec_cmd("sleep 2 && qs -c buddy -d")
end)
