-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Voxtype push-to-talk on Right Alt, replacing the Omarchy default F9
-- (/usr/share/omarchy/default/hypr/bindings/voxtype.lua).
-- ignore_mods on both binds: holding Right Alt raises the ALT modmask, so a
-- plain modmask-0 release bind would never match on key-up.
hl.unbind("F9")
o.bind("Alt_R", "Start dictation (push-to-talk)", "voxtype record start", { ignore_mods = true })
o.bind("Alt_R", "Stop dictation (push-to-talk)", "voxtype record stop", { release = true, ignore_mods = true })

-- Toshy (Mac-style remapping) claims Super+Tab / Super+Shift+Tab for macOS
-- Ctrl+Tab tab-switching, which fires before Hyprland sees it. Move workspace
-- navigation to the bracket keys.
hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
o.bind("SUPER + BRACKETRIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("SUPER + BRACKETLEFT", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))

-- Clipboard manager on the Maccy chord (physical left ctrl + start). Toshy's Mac
-- path emits Super+Alt+H for that in GUI apps; the terminal re-emit keymap in
-- toshy_config.py converts the terminal-context Ctrl+Alt+H to match.
hl.unbind("SUPER + CTRL + V")
o.bind("SUPER + ALT + H", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")
