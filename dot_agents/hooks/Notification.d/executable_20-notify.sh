#!/usr/bin/env bash
# Notification: play bell sound — agent waiting for permission or input.
# Fires on permission_prompt and elicitation_dialog events.
# shellcheck source=/dev/null
source "$(dirname "$0")/../lib-log.sh"
log_setup "notification-notify"

INPUT=$(cat)
MSG_TYPE=$(printf '%s' "$INPUT" | jq -r '.params.notification_type // .notification_type // ""' 2>/dev/null)

# Only notify on events that need human attention
case "$MSG_TYPE" in
    permission_prompt|elicitation_dialog|"") ;;
    *) log_op "SKIP non-attention event: $MSG_TYPE"; exit 0 ;;
esac

if ! command -v notify-send &>/dev/null; then
    log_op "SKIP notify-send not found"
    exit 0
fi

log_op "notify-send for: ${MSG_TYPE:-unknown}"
notify-send "Claude" "Waiting for input" --urgency=normal &
