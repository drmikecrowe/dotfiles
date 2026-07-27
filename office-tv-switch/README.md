# office-tv-switch

Hardware-specific glue for one desk: a VIA Labs USB3 A/B switch (`2109:0817`)
that moves the keyboard/webcam/audio between this laptop and another machine,
plus an Insignia TV on `HDMI-A-1` that has to follow it.

Flipping the switch should do three things:

1. move the USB peripherals (the switch does this in hardware)
2. tell the TV to change input, via a Home Assistant webhook
3. move the COSMIC desktop between the TV and the laptop panel

This directory is listed in `.chezmoiignore`, so chezmoi stores it in git but
never writes it into `$HOME`. Only the two files under `$HOME` are applied, and
only when `.officeTv.enabled` is true.

## Files

| Path | Applied by | Notes |
|---|---|---|
| `~/.local/bin/cosmic-usb-display.sh` | `chezmoi apply` | Follows the switch with `cosmic-randr` |
| `~/.config/systemd/user/cosmic-usb-display.service` | `chezmoi apply` | Runs the above inside the COSMIC session |
| `/usr/local/bin/toggle_tv_hdmi.sh` | `install.sh` | Posts to the HA webhook |
| `/etc/udev/rules.d/99-usb-ab-switch.rules` | `install.sh` | Fires on hub add/remove |

## Rebuild

```bash
chezmoi apply                                    # home-dir files
~/.local/share/chezmoi/office-tv-switch/install.sh   # root files + enable unit
```

`install.sh` is idempotent.

## Enabling on a machine

In `~/.config/chezmoi/chezmoi.toml` — **not** in this repo, which is public:

```toml
[data.officeTv]
    enabled = true
    webhook = "https://<ha-host>/api/webhook/<id>"
```

A Home Assistant webhook ID is an unauthenticated credential: anyone holding
the URL can trigger the automation. `toggle_tv_hdmi.sh` here carries a
`@WEBHOOK_URL@` placeholder that `install.sh` substitutes at install time.

The `enabled` flag is also what un-ignores the files, so the feature is keyed
to an explicit opt-in rather than to a hostname a rebuild might change.

## Why the settle delay exists

On 2026-07-27 a hub detach took down the whole Wayland session. Both actions
fire off the same udev event, and they collide on one output:

- the udev rule flips the TV to its other input; the TV *is* `HDMI-A-1`, so it
  drops HPD and `cosmic-comp` begins its own DRM reconfiguration
- `cosmic-usb-display.sh` simultaneously issued `cosmic-randr enable eDP-1 &&
  cosmic-randr disable HDMI-A-1`

Two concurrent mode-sets on one output. `cosmic-comp` logged `Failed to destroy
old mode property blob: No such file or directory`, then panicked on a poisoned
mutex in `smithay .../backend/drm/output.rs:797` and aborted with SIGABRT. Every
Wayland client died with it — terminal tabs, browser, panel, applets.

`cosmic-usb-display.sh` now coalesces event bursts, waits `SETTLE` seconds for
the topology to stop moving, and skips `cosmic-randr` calls when the output is
already in the wanted state (a no-op mode-set is still a real mode-set).

That reduces the risk but does not remove it. The underlying bug is upstream:
smithay `.unwrap()`s a poisoned mutex during DRM teardown, turning a
recoverable hotplug glitch into a full session loss. `SETTLE=4` is a judgment
call, not a measured value — if a real toggle still misbehaves, that is the
knob to turn.
