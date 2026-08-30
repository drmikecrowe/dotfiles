#!/usr/bin/env bash
# Session picker that groups aoe sessions by role, then project.
#
# aoe names its tmux sessions aoe_<project>_<hash> for the agent pane and
# aoe_term_<project>_<hash> for the paired terminal. Sorting by that name puts
# every aoe_term_* together, far from the project it belongs to. This rewrites
# each name into project / harness / role columns and sorts role first, then
# project, so all agents list together and all terms list together. Real session
# names are never touched -- aoe resolves sessions by name and would break if
# they were renamed.
#
# The harness (claude, omp, ...) is not in the session name, so it comes from
# `aoe ps`, joined on the 8-char hash the tmux name carries.
#
# Picking an agent also opens its paired terminal in the background if it is
# missing, so the pair always exists by the time you want to jump to it.

set -euo pipefail

TAB=$(printf '\t')

harness_map() {
	aoe ps --json 2>/dev/null |
		jq -r '.[] | "\(.session[0:8])\t\(.agent // "-")"' 2>/dev/null || true
}

# hash -> project workdir. Session rows are per-profile, so every profile is
# queried; `aoe ps` is profile-agnostic but does not carry the path.
workdir_map() {
	local profile
	aoe profile list 2>/dev/null |
		awk '/^[[:space:]]+/ { gsub(/^[[:space:]]*\*?[[:space:]]*/, ""); print $1 }' |
		while IFS= read -r profile; do
			aoe -p "$profile" list --json 2>/dev/null |
				jq -r '.[] | "\(.id[0:8])\t\(.path)"' 2>/dev/null || true
		done
}

list() {
	local agents
	agents=$(harness_map)

	tmux list-sessions -F '#{session_name}' | while IFS= read -r name; do
		case $name in
		aoe_term_*)
			rest=${name#aoe_term_}
			role=term
			;;
		aoe_*)
			rest=${name#aoe_}
			role=agent
			;;
		*)
			printf '%s\t-\t-\t%s\n' "$name" "$name"
			continue
			;;
		esac

		hash=${rest##*_}
		proj=${rest%_*}
		# aoe truncates long project names, often mid-separator
		while [ "${proj%_}" != "$proj" ]; do proj=${proj%_}; done

		harness=$(printf '%s\n' "$agents" |
			awk -F'\t' -v h="$hash" '$1 == h { print $2; exit }')

		printf '%s\t%s\t%s\t%s\n' "$proj" "${harness:--}" "$role" "$name"
	done |
		sort -t"$TAB" -k3,3 -k1,1 -k2,2 |
		awk -F'\t' '{ printf "%-24s %-8s %-5s\t%s\n", $1, $2, $3, $4 }'
}

# Create the paired terminal session if the picked agent has none. Detached, so
# it costs nothing until you switch to it.
ensure_term() {
	local agent=$1 term hash cwd
	case $agent in
	aoe_term_*) return 0 ;;
	aoe_*) ;;
	*) return 0 ;;
	esac

	term="aoe_term_${agent#aoe_}"
	# "=" forces exact matching; tmux would otherwise treat the name as a prefix
	if tmux has-session -t "=$term" 2>/dev/null; then
		return 0
	fi

	hash=${agent##*_}
	cwd=$(workdir_map | awk -F'\t' -v h="$hash" '$1 == h { print $2; exit }')
	if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
		cwd=$(tmux display-message -p -t "=$agent" '#{pane_current_path}')
	fi

	tmux new-session -d -s "$term" -c "$cwd" "${SHELL:-/bin/sh}" -l
}

sel=$(list | fzf \
	--delimiter='\t' \
	--with-nth=1 \
	--no-sort \
	--height=100% \
	--reverse \
	--prompt='session > ' \
	--header='project                  harness  role') || exit 0

target=${sel##*"$TAB"}
[ -n "$target" ] || exit 0

ensure_term "$target" || true
tmux switch-client ${TMUX_CLIENT:+-c "$TMUX_CLIENT"} -t "=$target"
