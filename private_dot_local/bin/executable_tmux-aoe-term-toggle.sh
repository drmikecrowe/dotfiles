#!/usr/bin/env bash
# prefix+C-t: toggle the paired aoe terminal as a right-hand split of the agent.
#
# Pairing is the same rule as tmux-aoe-pair-split.sh: aoe_term_<x>_<hash> is the
# terminal twin of <x>_<hash>.
#
#   agent, terminal split in      -> send the pane back to its terminal session
#   agent, terminal not split in  -> move the terminal's pane in on the right
#   agent, no terminal session    -> create one (aoe's name and @aoe_kind), then
#                                    move it in
#   terminal session              -> switch the client to the agent (old C-t)
#
# While split, the terminal session holds a placeholder window: a tmux session
# with no windows is destroyed, and aoe would lose the terminal.
set -uo pipefail

# Passed in as an expanded #{pane_id}: inside run-shell an untargeted tmux
# command follows the server's current client, not the pane the key was pressed in.
pane="${1:-$(tmux display-message -p '#{pane_id}')}"
current=$(tmux display-message -p -t "$pane" '#S')
hash=${current##*_}

pair_of() {
	local s
	while IFS= read -r s; do
		case "$current" in
		aoe_term_*)
			case "$s" in
			aoe_term_*) : ;;
			*_"$hash") echo "$s" && return ;;
			esac
			;;
		*)
			case "$s" in
			aoe_term_*_"$hash") echo "$s" && return ;;
			esac
			;;
		esac
	done < <(tmux list-sessions -F '#{session_name}')
}

case "$current" in
aoe_term_*)
	agent=$(pair_of)
	[ -n "$agent" ] && exec tmux switch-client -t "=$agent"
	exec tmux display-message "No paired session for hash $hash"
	;;
aoe_*) : ;;
*) exec tmux display-message "Not an aoe session: $current" ;;
esac

# Already split: send the terminal pane home.
split=$(tmux list-panes -t "$pane" -F '#{?@aoe_term_split,#{pane_id},}' | sed '/^$/d' | head -1)
if [ -n "$split" ]; then
	term=$(tmux show-options -pqv -t "$split" @aoe_term_split)
	wname=$(tmux show-options -pqv -t "$split" @aoe_term_wname)
	tmux set-option -pu -t "$split" @aoe_term_split
	tmux set-option -pu -t "$split" @aoe_term_wname
	if ! tmux has-session -t "=$term" 2>/dev/null; then
		exec tmux break-pane -d -s "$split" -n "$wname"
	fi
	placeholder=$(tmux list-windows -t "=$term" -F '#{?@aoe_placeholder,#{window_id},}' | sed '/^$/d' | head -1)
	tmux break-pane -d -s "$split" -t "=$term:" -n "$wname"
	[ -n "$placeholder" ] && tmux kill-window -t "$placeholder"
	exec tmux move-window -r -t "=$term:"
fi

# Not split: find or create the terminal session, then move its pane in.
term=$(pair_of)
if [ -z "$term" ]; then
	term="aoe_term_${current#aoe_}"
	tmux new-session -d -s "$term" -c "$(tmux display-message -p -t "$pane" '#{pane_current_path}')"
	tmux set-option -t "=$term:" @aoe_kind term
fi
termpane=$(tmux display-message -p -t "=$term:" '#{pane_id}')
wname=$(tmux display-message -p -t "$termpane" '#{window_name}')

placeholder=$(tmux new-window -d -P -F '#{window_id}' -t "=$term:" -n split \
	"printf 'This terminal is split into %s.\nPress prefix C-t there to bring it back.\n' '$current'; exec tail -f /dev/null")
tmux set-option -w -t "$placeholder" @aoe_placeholder 1

tmux join-pane -h -s "$termpane" -t "$pane"
tmux set-option -p -t "$termpane" @aoe_term_split "$term"
tmux set-option -p -t "$termpane" @aoe_term_wname "$wname"
