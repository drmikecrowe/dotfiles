# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# synu - Universal agent wrapper with Synthetic API quota tracking
# Zsh plugin entry point

# Standard $0 handling per Zsh Plugin Standard
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

typeset -g SYNU_PLUGIN_DIR="${0:h}"

# Add functions directory to fpath for autoloading
if [[ -z "${fpath[(r)${SYNU_PLUGIN_DIR}/functions]}" ]]; then
    fpath=("${SYNU_PLUGIN_DIR}/functions" "${SYNU_PLUGIN_DIR}/functions/_synu_agents" $fpath)
fi

# Add completions directory to fpath
if [[ -z "${fpath[(r)${SYNU_PLUGIN_DIR}/completions]}" ]]; then
    fpath=("${SYNU_PLUGIN_DIR}/completions" $fpath)
fi

# Source the main function and helpers (they define functions internally)
source "${SYNU_PLUGIN_DIR}/functions/synu.zsh"
source "${SYNU_PLUGIN_DIR}/functions/_synu_get_quota.zsh"
source "${SYNU_PLUGIN_DIR}/functions/_synu_cache.zsh"
