local platform = require('utils.platform')()

local options = {
   default_prog = {},
   launch_menu = {},
}

if platform.is_win then
   options.default_prog = { 'pwsh' }
elseif platform.is_mac then
   options.default_prog = { '/opt/homebrew/bin/fish' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash' } },
      { label = 'Fish', args = { '/opt/homebrew/bin/fish' } },
      { label = 'Nushell', args = { '/opt/homebrew/bin/nu' } },
      { label = 'Zsh', args = { 'zsh' } },
   }
elseif platform.is_linux then
   options.default_prog = { 'zsh', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-li' } },
      { label = 'Fish', args = { 'fish', '-li' } },
      { label = 'Nushell', args = { 'nu' } },
      { label = 'Xonsh', args = { '/home/mcrowe/.local/xonsh-env/xbin/xonsh' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
      { label = 'pwsh', args = { 'pwsh' } },
   }
end

return options
