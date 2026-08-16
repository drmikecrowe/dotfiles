#!/usr/bin/env bash
# Session picker that groups aoe sessions by project instead of by prefix.
#
# aoe names its tmux sessions aoe_<project>_<hash> for the agent pane and
# aoe_term_<project>_<hash> for the paired terminal. Sorting by that name puts
# every aoe_term_* together, far from the project it belongs to. This rewrites
# each name to "<project> <role>" for display and sorts on that, so a project's
# agent and term sit next to each other. Real session names are never touched --
# aoe resolves sessions by name and would break if they were renamed.

set -euo pipefail

TAB=$(printf '\t')

list() {
	tmux list-sessions -F '#{session_name}' | while IFS= read -r name; do
		case $name in
		aoe_term_*)
			rest=${name#aoe_term_}
			proj=${rest%_*}
			role=term
			;;
		aoe_*)
			rest=${name#aoe_}
			proj=${rest%_*}
			role=agent
			;;
		*)
			proj=$name
			role=-
			;;
		esac
		# aoe truncates long project names, often mid-separator
		while [ "${proj%_}" != "$proj" ]; do proj=${proj%_}; done
		printf '%s\t%s\t%s\n' "$proj" "$role" "$name"
	done |
		sort -t"$TAB" -k1,1 -k2,2 |
		awk -F'\t' '{ printf "%-28s %-5s\t%s\n", $1, $2, $3 }'
}

sel=$(list | fzf \
	--delimiter='\t' \
	--with-nth=1 \
	--no-sort \
	--height=100% \
	--reverse \
	--prompt='session > ' \
	--header='project                      role') || exit 0

target=${sel##*"$TAB"}
[ -n "$target" ] && tmux switch-client ${TMUX_CLIENT:+-c "$TMUX_CLIENT"} -t "$target"
