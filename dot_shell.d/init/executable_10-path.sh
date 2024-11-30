export PATH=${PATH}:$(echo ~/bin ~/.local/bin | tr ' ' '\n' | grep -vxFf <(echo $PATH | tr ':' '\n') | paste -sd:)

path_add "$HOME/.local/bin"
path_add "$HOME/bin"
path_add "$HOME/go/bin"
path_add "$HOME/.shell.d/aliases"