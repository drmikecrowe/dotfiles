-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
-- Laptop panel runs 1:1 docked and alone. For a smaller UI alone, use 0.8333333
-- (0.9 is not a valid scale for 1920x1080).
local omarchy_monitor_scale_docked = 1
local omarchy_monitor_scale_alone = 1

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

-- Keep four workspaces alive on each monitor. Omarchy 4.5 numbers them per
-- monitor block (~/.local/state/omarchy/monitor-workspaces): laptop 1-10, TV 11-20.
for slot = 1, 4 do
  hl.workspace_rule({ workspace = tostring(10 + slot), monitor = "HDMI-A-1", persistent = true })
  hl.workspace_rule({ workspace = tostring(slot), monitor = "eDP-1", persistent = true })
end
