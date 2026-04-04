# Set shell-specific prompt character BEFORE Dorothy loads
set -gx SHELL_PROMPT_CHAR 'f>'
set -gx STARSHIP_CONFIG $HOME/.config/dorothy/config/starship.toml

source '/home/mcrowe/.local/share/dorothy/init.fish' # Dorothy
