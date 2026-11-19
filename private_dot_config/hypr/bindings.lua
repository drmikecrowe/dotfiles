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
-- Toshy turns physical Alt into Right Ctrl in GUI apps, so Ctrl+Alt+arrow never
-- reaches Hyprland. Physical Ctrl+Win+arrow arrives as SUPER+CTRL; this replaces
-- Omarchy's grouped-window focus there.
hl.unbind("SUPER + CTRL + LEFT")
hl.unbind("SUPER + CTRL + RIGHT")
o.bind("SUPER + CTRL + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("SUPER + CTRL + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))

-- Omarchy 4.5 gives each monitor its own workspaces 1-10, and Super+N picks slot N
-- on the focused monitor. Keep the old fixed layout instead: Super+1-4 are TV slots
-- 1-4 and Super+5-8 are laptop slots 1-4, whichever monitor has focus. With the
-- TV unplugged, its keys fall back to the focused monitor.
local function slot_monitor(name)
  return hl.get_monitor(name) or hl.get_active_monitor()
end

for key = 1, 8 do
  local name = key <= 4 and "HDMI-A-1" or "eDP-1"
  local slot = (key - 1) % 4 + 1
  local code = "code:" .. tostring(key + 9)
  local focus_named, focus_here = o.workspaces.focus(slot, name), o.workspaces.focus(slot)
  o.rebind("SUPER + " .. code, "Switch to workspace " .. key, function()
    hl.dispatch(hl.get_monitor(name) and focus_named or focus_here)
  end)
  for _, follow in ipairs({ true, false }) do
    local mods = follow and "SUPER + SHIFT + " or "SUPER + SHIFT + ALT + "
    o.rebind(mods .. code, (follow and "Move window to workspace " or "Move window silently to workspace ") .. key, function()
      local window = hl.get_active_window()
      if not window then return end
      local id = o.workspaces.workspace_id(slot_monitor(name), slot)
      hl.dispatch(hl.dsp.window.move({ workspace = tostring(id), follow = follow, window = "address:" .. window.address }))
    end)
  end
end

-- Clipboard manager on the Maccy chord: physical left ctrl + start + H. Left ctrl is
-- a literal Ctrl and start is Super, so that chord arrives as SUPER+CTRL+H in every
-- context. Omarchy binds its Hardware menu there by default, so that moves aside.
hl.unbind("SUPER + CTRL + V")
hl.unbind("SUPER + CTRL + H")
o.bind("SUPER + CTRL + H", "Clipboard manager", "copyq toggle")
o.bind("SUPER + CTRL + SHIFT + H", "Hardware menu", "omarchy-menu toggle hardware")

-- Ghostty quick terminal: Ghostty 1.4 grabs its global: keybinds from the compositor itself.
-- Do not bind Ctrl+Shift+Grave here, or Hyprland denies Ghostty's request (already_bound).

-- Dictation keys from before Alt + Space and Right Alt became the defaults.
-- Remove these lines to give the keys back to applications.
if o.dictation_installed and o.dictation_installed() then
  o.bind("SUPER + CTRL + X", "Toggle dictation", "omarchy-dictation toggle")
end
