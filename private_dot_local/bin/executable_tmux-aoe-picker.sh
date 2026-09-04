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

# One jump key per row, in list order. Rows past the last key still pick with
# the cursor; they just get no key.
KEYS=abcdefghijklmnopqrstuvwxyz0123456789

harness_map() {
	aoe ps --json 2>/dev/null |
		jq -r '.[] | "\(.session[0:8])\t\(.agent // "-")"' 2>/dev/null || true
}

# hash -> label, workdir, runtime. The label is aoe's group plus the project,
# which the tmux name cannot give: aoe truncates the project there and carries
# no group at all, so "all" and three "main" rows are indistinguishable.
#
# Titles come in three shapes: "shell", "claude/host old-coder extras", and the
# older "main [claude/host] extras". The project is therefore the first word,
# unless the first word is a tool/runtime pair, in which case it is the second.
# That pair is worth keeping -- it is the only place host vs container shows --
# so it goes to the harness column, which `aoe ps` fills with the tool alone.
session_meta() {
	aoe list --all --json 2>/dev/null |
		jq -r '
			.[]
			| (.title | split(" ")) as $t
			| (if ($t[0] | test("/")) then $t[0] else "" end) as $rt
			| (if $rt == "" then $t[0] else ($t[1] // $t[0]) end) as $proj
			| (if .group == "" then "" else .group + "-" end) as $g
			| [.id[0:8], $g + $proj, .path, $rt]
			| @tsv
		' 2>/dev/null || true
}

list() {
	local agents meta
	agents=$(harness_map)
	meta=$(session_meta)

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

		label=$(printf '%s\n' "$meta" |
			awk -F'\t' -v h="$hash" '$1 == h { print $2; exit }')
		runtime=$(printf '%s\n' "$meta" |
			awk -F'\t' -v h="$hash" '$1 == h { print $4; exit }')

		printf '%s\t%s\t%s\t%s\n' "${label:-$proj}" "${runtime:-${harness:--}}" "$role" "$name"
	done |
		sort -t"$TAB" -k3,3 -k1,1 -k2,2 |
		awk -F'\t' -v keys="$KEYS" '
			{ k = substr(keys, NR, 1); if (k == "") k = " "
			  printf "%s  %-30s %-16s %-5s\t%s\n", k, $1, $2, $3, $4 }'
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
	cwd=$(session_meta | awk -F'\t' -v h="$hash" '$1 == h { print $3; exit }')
	if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
		cwd=$(tmux display-message -p -t "=$agent" '#{pane_current_path}')
	fi

	tmux new-session -d -s "$term" -c "$cwd" "${SHELL:-/bin/sh}" -l
}

binds=()
key_list=
for ((i = 0; i < ${#KEYS}; i++)); do
	k=${KEYS:i:1}
	binds+=(--bind "$k:pos($((i + 1)))+accept")
	key_list+=${key_list:+,}$k
done
# A bound key never reaches the search field, so a-z cannot be typed while the
# jump keys live. "/" releases them and turns searching on; there is no way
# back, which is why the picker starts with --disabled rather than the reverse.
binds+=(--bind "/:unbind($key_list)+enable-search")

sel=$(list | fzf \
	--delimiter='\t' \
	--with-nth=1 \
	--no-sort \
	--disabled \
	"${binds[@]}" \
	--height=100% \
	--reverse \
	--prompt='session > ' \
	--header='key  group-project                  harness           role  ("/" to search)') || exit 0

target=${sel##*"$TAB"}
[ -n "$target" ] || exit 0

ensure_term "$target" || true
tmux switch-client ${TMUX_CLIENT:+-c "$TMUX_CLIENT"} -t "=$target"
