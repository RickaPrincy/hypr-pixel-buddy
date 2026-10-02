hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

--##! AZERTY
-- En AZERTY les touches 1..0 envoient & é " ' ( - è _ ç à : on lie donc les codes physiques (10..19)
--#/# bind = SUPER+ALT, & é " ...,, -- Send to workspace (AZERTY)
for i = 1, 10 do
    hl.bind("SUPER + ALT + code:" .. (i + 9), function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = false }))
    end)
end
--#/# bind = SUPER+SHIFT, & é " ...,, -- Move to workspace and follow (AZERTY)
for i = 1, 10 do
    hl.bind("SUPER + SHIFT + code:" .. (i + 9), function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = true }))
    end, { description = "Window: Move to workspace " .. i .. " and follow" })
end

--##! Screenshots
local shot = "$HOME/.config/hypr/custom/scripts/screenshot.sh"
hl.bind("SUPER + CTRL + SHIFT + S", hl.dsp.exec_cmd(shot .. " region"),
    { description = "Utilities: Screen snip >> file & clipboard" })
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd(shot .. " edit"),
    { description = "Utilities: Screen snip >> annotate (swappy)" })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(shot .. " region"), { locked = true })
hl.bind("SUPER + Print", hl.dsp.exec_cmd(shot .. " full"),
    { locked = true, description = "Utilities: Screenshot >> file & clipboard" })

--##! Buddy
-- Ctrl+Super+R tue tous les qs (ii + buddy) : on relance buddy après ii
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd("sleep 2 && qs -c buddy -d"))
