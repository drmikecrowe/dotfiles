local wezterm = require('wezterm')
local mux = wezterm.mux

---@class config
---@field options table
local config = {}

config.debug_key_events = true

---Initialize config
---@return config
function config:init()
   self.__index = self
   local c = setmetatable({ options = {} }, self)
   return c
end

wezterm.on('gui-startup', function(cmd)
   local tab, pane, window = mux.spawn_window(cmd or {})
   window:gui_window():maximize()
end)

---Append to `config.options`
---@param new_options table new options to append
---@return config
function config:append(new_options)
   for k, v in pairs(new_options) do
      if self.options[k] ~= nil then
         wezterm.log_warn(
            'duplicate config option detected: ',
            { old = self.options[k], new = new_options[k] }
         )
      else
         self.options[k] = v
      end
   end
   return self
end

return config
