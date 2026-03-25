local wezterm = require('wezterm')
local act = wezterm.action
local config = {}

config.mouse_bindings = {
   -- Change the default click behavior so that it only selects
   -- text and doesn't open hyperlinks
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'NONE',
      action = act.Nop,
   },

   -- and make CTRL-Click open hyperlinks
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
   },

   -- Scrolling up while holding CTRL increases the font size
   {
      event = { Down = { streak = 1, button = { WheelUp = 1 } } },
      mods = 'CTRL',
      action = act.IncreaseFontSize,
   },

   -- Scrolling down while holding CTRL decreases the font size
   {
      event = { Down = { streak = 1, button = { WheelDown = 1 } } },
      mods = 'CTRL',
      action = act.DecreaseFontSize,
   },
}

return config
