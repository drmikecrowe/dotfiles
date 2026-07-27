#!/bin/bash
# Install the office TV / USB A/B switch integration on this machine.
#
# chezmoi apply handles the two files that live under $HOME (the display script
# and its user unit). It cannot handle these, because they are root-owned and
# outside the destination directory:
#
#   /usr/local/bin/toggle_tv_hdmi.sh
#   /etc/udev/rules.d/99-usb-ab-switch.rules
#
# So run this by hand after a rebuild. It is idempotent — safe to re-run.
#
# The webhook URL is NOT in this repo (it is public, and the ID is an
# unauthenticated credential). It comes from the machine-local chezmoi config
# at ~/.config/chezmoi/chezmoi.toml:
#
#   [data.officeTv]
#       enabled = true
#       webhook = "https://…/api/webhook/…"

set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

WEBHOOK=$(chezmoi execute-template '{{ dig "officeTv" "webhook" "" . }}')
if [[ -z "$WEBHOOK" ]]; then
    echo "error: .officeTv.webhook is unset in ~/.config/chezmoi/chezmoi.toml" >&2
    echo "       add it before running this installer (see header)" >&2
    exit 1
fi

echo "==> installing /usr/local/bin/toggle_tv_hdmi.sh"
sed "s|@WEBHOOK_URL@|$WEBHOOK|" "$HERE/toggle_tv_hdmi.sh" \
    | sudo install -m 0755 /dev/stdin /usr/local/bin/toggle_tv_hdmi.sh

echo "==> installing /etc/udev/rules.d/99-usb-ab-switch.rules"
sudo install -m 0644 "$HERE/99-usb-ab-switch.rules" /etc/udev/rules.d/99-usb-ab-switch.rules

echo "==> reloading udev rules"
sudo udevadm control --reload

echo "==> enabling cosmic-usb-display.service"
# chezmoi writes the unit itself; systemd owns the enablement symlink.
systemctl --user daemon-reload
systemctl --user enable --now cosmic-usb-display.service

echo "done. verify with:"
echo "  journalctl --user -u cosmic-usb-display -f"
