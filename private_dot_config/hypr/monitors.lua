-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
-- Laptop panel runs at 1 with the TV attached, smaller when alone. 0.9 is not a
-- valid scale for 1920x1080; Hyprland rounds it to 0.8333333.
local omarchy_monitor_scale_docked = 1
local omarchy_monitor_scale_alone = 0.8333333

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

local function set_laptop_scale(docked)
  local scale = docked and omarchy_monitor_scale_docked or omarchy_monitor_scale_alone
  hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = scale })
end

local docked = false
for _, monitor in ipairs(hl.get_monitors() or {}) do
  if monitor.name == "HDMI-A-1" then docked = true end
end
set_laptop_scale(docked)

hl.on("monitor.added", function(monitor)
  if monitor.name == "HDMI-A-1" then set_laptop_scale(true) end
end)
hl.on("monitor.removed", function(monitor)
  if monitor.name == "HDMI-A-1" then set_laptop_scale(false) end
end)

-- Configure a specific monitor.
-- 4K TV is the reference display at scale 1.
hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@30", position = "auto-left", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- Pin workspaces to monitors. A Hyprland workspace lives on exactly one
-- monitor, so without these rules "switch to workspace N" jumps focus to
-- whichever monitor happened to create N first. Workspaces 9-10 stay unpinned.
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "eDP-1", persistent = true })
hl.workspace_rule({ workspace = "6", monitor = "eDP-1", persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "eDP-1", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "eDP-1", persistent = true })
