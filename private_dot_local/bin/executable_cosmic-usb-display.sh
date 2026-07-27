#!/bin/bash
# Follow the USB A/B switch with COSMIC display configuration.
#
#   hub attached (switch on this laptop)  -> external monitor on, laptop panel off
#   hub detached (switch on other machine) -> laptop panel on, external monitor off
#
# Runs as a systemd *user* service inside the COSMIC session: cosmic-randr must
# reach cosmic-comp over the user's Wayland socket, so this cannot run from the
# root udev rule (which handles the Home Assistant webhook separately).
#
# RACE HAZARD (crashed the session 2026-07-27, cosmic-comp SIGABRT):
# the same hub event also fires the root udev rule, which flips the TV to its
# other input. The TV *is* $EXT, so it drops HPD and cosmic-comp begins its own
# DRM reconfiguration. Issuing cosmic-randr into that window means two
# concurrent mode-sets on one output; cosmic-comp panicked on a poisoned mutex
# ("Failed to destroy old mode property blob") and every Wayland client died
# with it. QUIET/SETTLE below keep us out of that window.

set -u

EXT="HDMI-A-1"          # INSIGNIA-TV office monitor
INT="eDP-1"             # laptop panel
HUB_ID="2109:0817"      # USB3 hub, as lsusb spells it
HUB_PRODUCT="2109/817"  # same hub, as udev ENV{PRODUCT} spells it (zeros stripped)

QUIET=1                 # seconds of event silence before a burst counts as over
SETTLE=4                # then wait this long for the TV's HPD drop and
                        # cosmic-comp's own reconfiguration to finish

hub_present() {
    lsusb -d "$HUB_ID" >/dev/null 2>&1
}

# cosmic-randr colourises unconditionally, so strip SGR before matching.
output_enabled() {
    cosmic-randr list 2>/dev/null \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | rg -q "^$1 \(enabled\)"
}

# Always enable the incoming display BEFORE disabling the outgoing one, so we
# are never momentarily left with zero enabled outputs. Each call is skipped
# when the output is already in the wanted state: a no-op mode-set is still a
# real mode-set to the compositor, and this is the thing that races.
apply() {
    local on=$1 off=$2 changed=0
    if ! output_enabled "$on"; then
        cosmic-randr enable "$on" || return 1
        changed=1
    fi
    if output_enabled "$off"; then
        cosmic-randr disable "$off" || return 1
        changed=1
    fi
    (( changed )) && echo "usb-display: $on on, $off off"
    return 0
}

# Resolve against the hub's *current* state rather than the event that woke us,
# so a bouncing switch settles on reality instead of replaying every transition.
sync_now() {
    if hub_present; then apply "$EXT" "$INT"; else apply "$INT" "$EXT"; fi
}

# Apply the correct layout at startup, so state is right on login/re-login even
# though no hot-plug event fired.
sync_now

action=; devtype=; product=; pending=0

# stdbuf -oL: without it the pipe is block-buffered and events arrive late.
# Process substitution (not a pipe) so the loop runs in *this* shell and the
# pending flag survives between reads.
while true; do
    IFS= read -r -t "$QUIET" line
    rc=$?

    if (( rc > 128 )); then
        # Read timed out: the event burst is over. Let the display topology
        # stop moving, then reconcile once.
        if (( pending )); then
            pending=0
            sleep "$SETTLE"
            sync_now
        fi
        continue
    elif (( rc != 0 )); then
        break   # udevadm exited; systemd Restart=always brings us back
    fi

    case "$line" in
        ACTION=*)  action=${line#ACTION=} ;;
        DEVTYPE=*) devtype=${line#DEVTYPE=} ;;
        PRODUCT=*) product=${line#PRODUCT=} ;;
        "")  # blank line terminates an event block
            if [ "${devtype:-}" = "usb_device" ] && [[ "${product:-}" == "$HUB_PRODUCT"/* ]]; then
                case "${action:-}" in
                    add|remove) pending=1 ;;
                esac
            fi
            action=; devtype=; product=
            ;;
    esac
done < <(stdbuf -oL udevadm monitor --udev --property --subsystem-match=usb)
