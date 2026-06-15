local wezterm = require('wezterm')
local act = wezterm.action
local config = {}

-- Track current selection mode for drag extension
local selection_mode = 'Cell'

-- DISABLE all default mouse bindings so we control everything
config.disable_default_mouse_bindings = true

config.mouse_bindings = {
   -- ===== SINGLE CLICK: cell-level selection =====
   {
      event = { Down = { streak = 1, button = 'Left' } },
      mods = 'NONE',
      action = wezterm.action_callback(function(win, pane)
         selection_mode = 'Cell'
         wezterm.log_error('MOUSE DOWN: mode=' .. selection_mode)
         win:perform_action(act.SelectTextAtMouseCursor(selection_mode), pane)
      end),
   },
   -- extend on drag
   {
      event = { Drag = { streak = 1, button = 'Left' } },
      mods = 'NONE',
      action = wezterm.action_callback(function(win, pane)
         wezterm.log_error('MOUSE DRAG: mode=' .. selection_mode)
         win:perform_action(act.ExtendSelectionToMouseCursor(selection_mode), pane)
      end),
   },
   -- complete on release (primary only, no link opening)
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'NONE',
      action = act.CompleteSelection('PrimarySelection'),
   },

   -- ===== DOUBLE CLICK: word selection =====
   {
      event = { Down = { streak = 2, button = 'Left' } },
      mods = 'NONE',
      action = wezterm.action_callback(function(win, pane)
         selection_mode = 'Word'
         win:perform_action(act.SelectTextAtMouseCursor(selection_mode), pane)
      end),
   },
   {
      event = { Drag = { streak = 2, button = 'Left' } },
      mods = 'NONE',
      action = wezterm.action_callback(function(win, pane)
         win:perform_action(act.ExtendSelectionToMouseCursor(selection_mode), pane)
      end),
   },
   {
      event = { Up = { streak = 2, button = 'Left' } },
      mods = 'NONE',
      action = act.CompleteSelection('PrimarySelection'),
   },

   -- ===== TRIPLE CLICK: line selection =====
   {
      event = { Down = { streak = 3, button = 'Left' } },
      mods = 'NONE',
      action = wezterm.action_callback(function(win, pane)
         selection_mode = 'Line'
         win:perform_action(act.SelectTextAtMouseCursor(selection_mode), pane)
      end),
   },
   {
      event = { Drag = { streak = 3, button = 'Left' } },
      mods = 'NONE',
      action = wezterm.action_callback(function(win, pane)
         win:perform_action(act.ExtendSelectionToMouseCursor(selection_mode), pane)
      end),
   },
   {
      event = { Up = { streak = 3, button = 'Left' } },
      mods = 'NONE',
      action = act.CompleteSelection('PrimarySelection'),
   },

   -- ===== SHIFT: extend existing selection =====
   {
      event = { Down = { streak = 1, button = 'Left' } },
      mods = 'SHIFT',
      action = act.ExtendSelectionToMouseCursor('Cell'),
   },
   {
      event = { Drag = { streak = 1, button = 'Left' } },
      mods = 'SHIFT',
      action = act.ExtendSelectionToMouseCursor('Cell'),
   },
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'SHIFT',
      action = act.CompleteSelection('ClipboardAndPrimarySelection'),
   },

   -- ===== ALT: block selection =====
   {
      event = { Down = { streak = 1, button = 'Left' } },
      mods = 'ALT',
      action = wezterm.action_callback(function(win, pane)
         selection_mode = 'Block'
         win:perform_action(act.SelectTextAtMouseCursor(selection_mode), pane)
      end),
   },
   {
      event = { Drag = { streak = 1, button = 'Left' } },
      mods = 'ALT',
      action = wezterm.action_callback(function(win, pane)
         win:perform_action(act.ExtendSelectionToMouseCursor(selection_mode), pane)
      end),
   },
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'ALT',
      action = act.CompleteSelection('PrimarySelection'),
   },

   -- ===== CTRL+Click: open hyperlinks =====
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
   },

   -- ===== Middle click: paste =====
   {
      event = { Down = { streak = 1, button = 'Middle' } },
      mods = 'NONE',
      action = act.PasteFrom('PrimarySelection'),
   },

   -- ===== Scroll: move through scrollback =====
   {
      event = { Down = { streak = 1, button = { WheelUp = 1 } } },
      mods = 'NONE',
      action = act.ScrollByLine(-3),
   },
   {
      event = { Down = { streak = 1, button = { WheelDown = 1 } } },
      mods = 'NONE',
      action = act.ScrollByLine(3),
   },

   -- ===== CTRL+Scroll: font size =====
   {
      event = { Down = { streak = 1, button = { WheelUp = 1 } } },
      mods = 'CTRL',
      action = act.IncreaseFontSize,
   },
   {
      event = { Down = { streak = 1, button = { WheelDown = 1 } } },
      mods = 'CTRL',
      action = act.DecreaseFontSize,
   },
}

return config
