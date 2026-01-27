local wezterm = require('wezterm')
local platform = require('utils.platform')()
local backdrops = require('utils.backdrops')
local act = wezterm.action

local mod = {}

if platform.is_mac then
   mod.SUPER = 'SUPER'
   mod.SUPER_REV = 'SUPER|CTRL'
elseif platform.is_win or platform.is_linux then
   mod.SUPER = 'SHIFT|CTRL'
   mod.SUPER_REV = 'SHIFT|ALT|CTRL'
end

local keys = {
   { key = 'Enter', mods = 'SHIFT', action = wezterm.action({ SendString = '\x1b\r' }) },
   -- =====================
   -- 1. Leader (tmux-style) keys
   -- =====================
   { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection('Left') },
   { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection('Down') },
   { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection('Up') },
   { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection('Right') },
   { key = 's', mods = 'LEADER', action = act.SplitVertical({ domain = 'CurrentPaneDomain' }) },
   { key = 'v', mods = 'LEADER', action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }) },
   {
      key = 'w',
      mods = 'LEADER',
      action = act.Multiple({
         act.SendKey({ mods = 'CTRL', key = 'r' }),
         act.ClearScrollback('ScrollbackOnly'),
      }),
   },
   {
      key = 'F1',
      mods = 'NONE',
      action = act.InputSelector({
         title = 'Keybindings (ESC to close)',
         choices = {
            { label = '           WEZTERM ^s        │          TMUX ^b' },
            {
               label = '─────────────────────────────┼─────────────────────────────',
            },
            { label = 's     split below            │ s     split below' },
            { label = 'v     split right            │ v     split right' },
            { label = 'hjkl  navigate               │ hjkl  navigate' },
            { label = 'p     resize mode (hjkl)     │ z     zoom toggle' },
            { label = 'w     clear scrollback       │ x     kill pane' },
            { label = 'f     font resize (jk/r)     │ w     clear + history' },
            {
               label = '─────────────────────────────┼─────────────────────────────',
            },
            { label = '^Tab/^S-Tab  next/prev tab   │ c     new window' },
            { label = 'S^t   new tab                │ n/p   next/prev window' },
            { label = 'S^w   close tab              │ 0-9   go to window' },
            { label = 'SA^z  zoom toggle            │ d     detach' },
            { label = 'S^w   close pane             │ [     copy mode (vi)' },
            {
               label = '─────────────────────────────┼─────────────────────────────',
            },
            { label = 'S=Shift ^=Ctrl A=Alt         │  r/R reload/refresh (tmux)' },
            {
               label = '─────────────────────────────┼─────────────────────────────',
            },
            { label = 'F1 help  F2 palette  F3 launcher  F11 copy  F12 debug' },
         },
         action = wezterm.action_callback(function() end),
      }),
   },

   -- =====================
   -- 2. Pane management
   -- =====================
   { key = '\\', mods = mod.SUPER, action = act.SplitVertical({ domain = 'CurrentPaneDomain' }) },
   {
      key = '\\',
      mods = mod.SUPER_REV,
      action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }),
   },
   { key = 'z', mods = mod.SUPER_REV, action = act.TogglePaneZoomState },
   { key = 'w', mods = mod.SUPER, action = act.CloseCurrentPane({ confirm = false }) },
   {
      key = 'p',
      mods = mod.SUPER_REV,
      action = act.PaneSelect({ alphabet = '1234567890', mode = 'SwapWithActiveKeepFocus' }),
   },

   -- =====================
   -- 3. Tab management
   -- =====================
   { key = 't', mods = mod.SUPER, action = act.SpawnTab('DefaultDomain') },
   { key = 'w', mods = mod.SUPER_REV, action = act.CloseCurrentTab({ confirm = false }) },
   { key = 'Tab', mods = 'SHIFT|CTRL', action = act.ActivateTabRelative(-1) },
   { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(1) },

   -- =====================
   -- 4. Window management
   -- =====================
   { key = 'n', mods = mod.SUPER, action = act.SpawnWindow },

   -- =====================
   -- 5. Copy/paste
   -- =====================
   { key = 'c', mods = mod.SUPER, action = act.CopyTo('Clipboard') },
   { key = 'v', mods = mod.SUPER, action = act.PasteFrom('Clipboard') },

   -- =====================
   -- 6. Background controls
   -- =====================
   {
      key = '/',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:random(window)
      end),
   },
   {
      key = ',',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_back(window)
      end),
   },
   {
      key = '.',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_forward(window)
      end),
   },
   {
      key = '/',
      mods = mod.SUPER_REV,
      action = act.InputSelector({
         title = 'Select Background',
         choices = backdrops:choices(),
         fuzzy = true,
         fuzzy_description = 'Select Background: ',
         action = wezterm.action_callback(function(window, _pane, idx)
            backdrops:set_img(window, tonumber(idx))
         end),
      }),
   },

   -- =====================
   -- 7. Miscellaneous (F-keys, search, overlays, etc)
   -- =====================
   { key = 'F11', mods = 'NONE', action = 'ActivateCopyMode' },
   { key = 'F2', mods = 'NONE', action = act.ActivateCommandPalette },
   { key = 'F3', mods = 'NONE', action = act.ShowLauncher },
   { key = 'F4', mods = 'NONE', action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }) },
   { key = 'F5', mods = 'NONE', action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }) },
   { key = 'F12', mods = 'NONE', action = act.ShowDebugOverlay },
   { key = 'f', mods = mod.SUPER, action = act.Search({ CaseInSensitiveString = '' }) },

   -- =====================
   -- 8. Key tables (resize font/pane)
   -- =====================
   {
      key = 'f',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_font',
         one_shot = false,
         timemout_miliseconds = 1000,
      }),
   },
   {
      key = 'p',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_pane',
         one_shot = false,
         timemout_miliseconds = 1000,
      }),
   },
}

local key_tables = {
   resize_font = {
      { key = 'k', action = act.IncreaseFontSize },
      { key = 'j', action = act.DecreaseFontSize },
      { key = 'r', action = act.ResetFontSize },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q', action = 'PopKeyTable' },
   },
   resize_pane = {
      { key = 'k', action = act.AdjustPaneSize({ 'Up', 1 }) },
      { key = 'j', action = act.AdjustPaneSize({ 'Down', 1 }) },
      { key = 'h', action = act.AdjustPaneSize({ 'Left', 1 }) },
      { key = 'l', action = act.AdjustPaneSize({ 'Right', 1 }) },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q', action = 'PopKeyTable' },
   },
}

local mouse_bindings = {
   -- Ctrl-click will oapen the link under the mouse cursor
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
   },
}

return {
   disable_default_key_bindings = true,
   leader = { key = 's', mods = 'CTRL', timeout_milliseconds = 2000 },
   keys = keys,
   key_tables = key_tables,
   mouse_bindings = mouse_bindings,
}
