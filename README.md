# Mouse Control

Mouse Control is the owned Omarchy+ Quickshell plugin for Hugin's Razer Naga
V3 Pro and Logitech PRO X Superlight. It provides one compact bar status and
popup while keeping each vendor's existing control authority separate.

The permanent plugin ID is `io.github.ol4vr.mouse-control`. Production
placement is the left bar immediately after `io.github.ol4vr.openrgb-presets`.

## Current behavior

- Keeps the bar compact with the mouse icon and selected-device battery, plus
  a small theme-success lightning bolt only while charging is explicitly true;
  the hover tooltip and popup retain the device name, DPI, and battery details.
- Shows the manually selected mouse, connection state, current DPI when the
  backend can read it, battery percentage, and charging state when reported.
- Provides the same 600, 800, 1000, 1200, 1400, and 1600 DPI presets for both
  mice. An out-of-list current value remains visible without selecting a
  preset, and a write occurs only when the owner clicks a preset.
- Stores the selected mouse and last successfully verified DPI per device in
  `${XDG_STATE_HOME:-~/.local/state}/omarchy-plus/mouse-control/preferences.json`.
- Sends one normal-urgency warning when either mouse reaches the configured
  warning threshold (15% by default). Each notification names the mouse and
  percentage and asks the owner to connect the USB charging cable; there is no
  separate critical alert.
- Suppresses battery warnings while charging, tracks the warning latch
  independently for each mouse, and rearms it only after charge reaches five
  points above the warning threshold. Missing battery data never produces a
  notification. The popup shows the current threshold as compact status; the
  helper's existing `set-warning-threshold` command remains available for a
  deliberate adjustment.
- Marks unavailable values as unavailable; it never fabricates DPI, battery,
  charging, or connection state.
- Does not edit button mappings, Naga profiles, RGB, polling rate, firmware,
  keyd, or Discord PTT.

Automatic active-mouse switching is intentionally absent. Hyprland identifies
both pointers in its device inventory but does not expose which physical mouse
produced the latest ordinary motion through its existing status API. Adding an
event-node monitor solely for this feature would violate the lightweight,
non-grabbing design. Manual selection is available in the popup.

The physical-mouse enable toggle is also intentionally absent. Hugin's current
Hyprland runtime does not expose a verified reversible per-device `enabled`
option for these mouse identities. Disabling event nodes or USB devices would
be a materially riskier mechanism and could disable the wrong Naga proxy or
both recovery pointers.

Low-battery notifications use Omarchy's existing
`omarchy-notification-send` command and the existing five-second status poll.
That command delivers through the desktop notification interface used by
SwayNC. Mouse Control does not start a notification daemon or add another
polling process.

Preference schema 2 deliberately migrates the previous schema-1 default of
20% to 15%, preserving device selection and preferred DPI values while
rearming both per-device warning latches. Other valid explicitly stored
thresholds are retained during migration.

## Backends

### Razer Naga V3 Pro

Naga Control remains the sole Naga/OpenRazer writer. The plugin reads its
`GetSnapshot` response and uses the narrow `SetDpi(uint16 x, uint16 y)` method
for an explicit preset click. `SetDpi` runs through Naga Control's serialized,
topology-fenced hardware worker and returns the observed snapshot after the
write. It does not change the configuration revision, saved DPI stages,
profiles, remapping session, buttons, or lighting.

This explicit operation remains available while broad `hardware_writes=false`;
that setting continues to prevent automatic profile writes. Naga Control's
`lighting_writes=false` boundary is unchanged, and Mouse Control never offers a
Razer RGB operation.

### Logitech PRO X Superlight

The kernel `hidpp_battery` power-supply interface provides connection, battery,
and charging telemetry. DPI read/write uses `ratbagctl`, backed by libratbag's
supported `hidpp20` device entry for the original Superlight (`046d:4093`, also
matched as wired `046d:c094`). The Hugin receiver presents the supported
`046d:4093` child device even though its USB receiver itself is `046d:c547`.

Hugin uses Arch's packaged `libratbag` 0.18-1. The wired `046d:c094` device is
discovered by `ratbagctl`; Mouse Control recognizes that exact USB identity and
prefers Wired when receiver telemetry is also present. Over the `046d:c547`
LIGHTSPEED receiver, the kernel exposes the `046d:4093` mouse but libratbag does
not enumerate a configurable device, so wireless DPI control remains
unavailable.

For the wired mouse, libratbag reports disabled Profile 1 as active even though
Profile 0 owns the usable DPI stages and active resolution. Mouse Control reads,
writes, and verifies Profile 0's active resolution explicitly without changing
the active profile or enabling or disabling any profile. This avoids accepting
a readback from the unusable Profile 1. A controlled Hugin test confirmed that
the Profile 0 write changes physical pointer sensitivity; the owner selected
1000 DPI for everyday use. Upstream libratbag still has related reports where a
successful stage readback does not change pointer sensitivity on other devices.
Do not add Piper, Solaar, a custom driver, udev rule, or service for this
limitation.

## Validation

Run without changing live configuration or hardware:

```bash
./scripts/validate
./scripts/dev-deploy --check
```

The tests replace every Naga, ratbag, and notification command. Validation
never invokes `SetDpi`, `ratbagctl ... dpi set`, a live notification, a
device-disable command, or an input monitor.

## Installation and recovery

The authoritative checkout is
`/home/ol4vr/Projects/omarchy-plus-apps/omarchy-plus-mouse-control`. After owner
acceptance, publish an immutable commit and add that exact commit to central
`config/plugins.json` with `section: "left"` and
`after: "io.github.ol4vr.openrgb-presets"`. Central `scripts/plugins/reconcile`
then owns installation, enablement, placement, and BASE recovery like the other
owned plugins.

The optional development-copy lifecycle is:

```bash
./scripts/dev-deploy
./scripts/dev-remove
```

Both commands act only on the marker-owned
`~/.config/omarchy/plugins/io.github.ol4vr.mouse-control` directory. Production
recovery is to rerun central reconciliation from the pinned commit. Removing
the plugin does not remove Naga Control, OpenRazer, libratbag, saved Naga
profiles, or the plugin preference file. Deleting that preference file is
optional and resets the selected mouse, remembered DPI labels, warning
threshold, and notification latches; it does not write either mouse.

BASE recovery requires the accepted Naga Control artifact/service for Razer
telemetry and the approved Arch `libratbag` package for Logitech DPI control.
The kernel power-supply interface remains sufficient for Logitech battery
telemetry. OpenRGB remains the only RGB authority.

## License

MIT. See `LICENSE`.
