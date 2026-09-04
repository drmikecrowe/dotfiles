#!/usr/bin/env bash
# Split the current window and open a shell where the PAIRED aoe session lives.
#
# Pairing is the same rule prefix+C-t uses to switch sessions: aoe_term_<x>_<hash>
# is the terminal twin of <x>_<hash>. This opens that terminal as a split in the
# current window instead of switching the client to it.
#
#   $1 = -h  side-by-side (vim "vertical split")   -> bound to prefix + C-v
#   $1 = -v  stacked      (vim "horizontal split") -> bound to prefix + C-h
#
# No pair found (a session outside the aoe_* scheme): split at the current
# pane's path, so the key never does nothing.
set -uo pipefail

split_flag="${1:--h}"

# The pane is passed in by the binding as an expanded #{pane_id}: inside
# run-shell an untargeted tmux command follows the server's current client,
# which is not necessarily where the key was pressed.
pane="${2:-$(tmux display-message -p '#{pane_id}')}"
current=$(tmux display-message -p -t "$pane" '#S')
hash=${current##*_}
pair=""
while IFS= read -r s; do
	case "$current" in
	aoe_term_*)
		# On a terminal session: pair is the non-term session with the same hash.
		case "$s" in
		aoe_term_*) : ;;
		*_"$hash")
			pair=$s
			break
			;;
		esac
		;;
	*)
		# On a work session: pair is the aoe_term_* session with the same hash.
		case "$s" in
		aoe_term_*_"$hash")
			pair=$s
			break
			;;
		esac
		;;
	esac
done < <(tmux list-sessions -F '#{session_name}')

if [ -n "$pair" ]; then
	path=$(tmux display-message -p -t "$pair" '#{pane_current_path}')
else
	path=$(tmux display-message -p -t "$pane" '#{pane_current_path}')
fi

exec tmux split-window "$split_flag" -t "$pane" -c "$path"
