# Broken-Touchpad Desktop Mapping and Game Isolation

The laptop touchpad on the tested machine is physically broken or otherwise
non-functional. The ZhiXu controller therefore serves two distinct roles:

- a real gamepad through the patched `xpad` driver; and
- a replacement desktop mouse/keyboard through AntiMicroX.

The repository includes the tested AntiMicroX profile and its complete service
lifecycle. This remains separate from the kernel fix: the patched real
controller must remain available to games, while the mapper's virtual keyboard
and mouse devices must not.

## Architecture

| Layer | Runtime device | Desktop | Steam/Lutris game |
| --- | --- | --- | --- |
| Patched `xpad` | Real `Microsoft X-Box 360 pad` | Present | Present |
| Included `controller-mouse.service` | AntiMicroX virtual keyboard/mouse | Present | Stopped and absent |
| Optional RT suppression | `zhixu_suppress_rt` on the real `xpad` device | Unchanged | Unchanged unless manually enabled |

The guard controls only the user service named `controller-mouse.service`.
It does not unload `xpad`, unbind USB interfaces, grab the real event device,
or write to `/sys/module/xpad/parameters/zhixu_suppress_rt`.

The tested clone re-enumerates several times when AntiMicroX closes the final
open evdev reader. To prevent that driver/firmware lifecycle from interrupting
a game, the persistent guard keeps one non-exclusive, read-only descriptor open
on the real `Microsoft X-Box 360 pad`. It drains only its own evdev queue and
does not prevent Steam, Lutris, Wine, or native games from receiving the same
events.

## Included Desktop Profile

`antimicrox/desktop.gamecontroller.amgp` is the profile currently used on the
tested machine:

| Controller input | Desktop action |
| --- | --- |
| Left stick | Cursor movement, speed 20, Enhanced Precision curve |
| Right stick up/down | Scroll |
| D-pad up/down | Scroll |
| Left trigger | Right click |
| Right trigger | Left click |
| A | Left click |
| B | Right click |
| X | Middle click |
| Back | Escape |
| Start | Enter |

The profile targets SDL controller GUID
`030081b85e0400008e02000010010000`, observed for the tested ZhiXu controller in
Xbox/xpad mode. Another revision of the controller may expose a different GUID;
check it with `antimicrox --list` and update both the profile and user unit when
necessary.

The keepalive finds the evdev device by its input name. Override the default
for a different controller name in the guard service:

```ini
Environment=CONTROLLER_MOUSE_DEVICE_NAME=Another Controller Name
```

### Steam

Steam's Linux launch wrapper creates transient systemd scopes named
`app-steam-app<APPID>-<PID>.scope`. The guard subscribes to the systemd user
manager's `UnitNew` and `UnitRemoved` signals. It stops the mapper as soon as a
Steam game scope is created and restores it only after the final Steam/Lutris
game exits.

The cgroup directory is also checked at startup so restarting the guard while a
Steam game is already running cannot accidentally enable the mapper.

### Lutris

Lutris supports a global command prefix. `game-with-controller` creates an
inhibitor before executing the runner command and removes it when that command
exits. This stops the mapper before the game process starts.

Multiple and overlapping games are supported. Exiting one game cannot restore
the mapper while another Steam or Lutris game remains active.

## Requirements

- AntiMicroX 3.6.1 or a compatible version.
- `systemd --user` and cgroup v2.
- Python 3.
- Read permission for the real controller's `/dev/input/event*` node.
- `dbus-python` and PyGObject for event-driven Steam detection.
  If unavailable, the guard falls back to polling Steam scopes every 0.5
  seconds.
- Lutris is optional and requires the configuration below.

## Installation

Install the profile, scripts, and both user units:

```bash
install -Dm644 antimicrox/desktop.gamecontroller.amgp \
  "$HOME/.config/antimicrox/desktop.gamecontroller.amgp"
install -Dm755 scripts/controller-mouse-game-guard \
  "$HOME/.local/bin/controller-mouse-game-guard"
install -Dm755 scripts/controller-mouse-toggle.sh \
  "$HOME/.local/bin/controller-mouse-toggle"
install -Dm755 scripts/game-with-controller.sh \
  "$HOME/.local/bin/game-with-controller"
install -Dm644 systemd/controller-mouse.service \
  "$HOME/.config/systemd/user/controller-mouse.service"
install -Dm644 systemd/controller-mouse-game-guard.service \
  "$HOME/.config/systemd/user/controller-mouse-game-guard.service"

systemctl --user daemon-reload
systemctl --user enable --now controller-mouse.service
systemctl --user enable --now controller-mouse-game-guard.service
```

No Steam launch options are required.

The mapper can be manually toggled with:

```bash
controller-mouse-toggle
```

For Hyprland, an optional binding can execute that command:

```ini
bind = $mainMod CTRL, M, exec, $HOME/.local/bin/controller-mouse-toggle
```

### Lutris configuration

Merge the following into `~/.config/lutris/system.yml`, replacing
`YOUR_USER` with the account name:

```yaml
system:
  prefix_command: /home/YOUR_USER/.local/bin/game-with-controller
```

If the file already contains a `system:` mapping, add only the
`prefix_command` entry beneath it. A game-specific `prefix_command` overrides
the global value and must include this wrapper separately.

Restart Lutris after changing its configuration.

## Runtime State

The guard keeps transient state under:

```text
$XDG_RUNTIME_DIR/controller-mouse-game-guard/
```

It records whether the mapper was active before the first game started. If it
was manually disabled, finishing a game does not enable it. Inhibitor tokens
are PID-scoped and stale tokens are removed automatically.

Inspect the current state:

```bash
controller-mouse-game-guard --status
```

Typical idle output:

```text
sources=none mapper=active restore=no
```

Typical in-game output:

```text
sources=steam mapper=inactive restore=yes
```

## Verification

The following tests do not launch a real game, but exercise the same Steam
scope and Lutris prefix paths. They briefly stop and restore the desktop mapper.

### Baseline

```bash
systemctl --user is-active controller-mouse.service
systemctl --user is-active controller-mouse-game-guard.service
controller-mouse-game-guard --status
```

Both services should be active and the guard should report `sources=none`.

### Steam scope

In one terminal:

```bash
systemd-run --user --scope \
  --unit=app-steam-app999999-isolation-test sleep 10
```

While it runs, check:

```bash
systemctl --user is-active controller-mouse.service
grep -E 'antimicrox .* Emulation|Microsoft X-Box 360 pad' \
  /proc/bus/input/devices
```

Expected:

- `controller-mouse.service` is inactive or deactivating;
- no AntiMicroX emulation devices are listed;
- the real `Microsoft X-Box 360 pad` remains listed.
- no new `usb ... USB disconnect` kernel messages appear when the mapper stops.

After `sleep` exits, the mapper should become active again.

### Lutris prefix

In one terminal:

```bash
"$HOME/.local/bin/game-with-controller" sleep 10
```

Run the same service and input-device checks in another terminal. The expected
state is identical to the Steam test.

### Patched driver remains active

Identify the controller's USB interface and verify its driver:

```bash
for interface in /sys/bus/usb/devices/*:*; do
  if [ -L "$interface/driver" ] &&
     [ "$(basename "$(readlink -f "$interface/driver")")" = xpad ]; then
    printf '%s -> xpad\n' "${interface##*/}"
  fi
done
```

Stopping AntiMicroX must not remove this binding or the real controller's
`event`/`js` nodes.

The persistent guard should also hold the real event node open:

```bash
guard_pid="$(systemctl --user show controller-mouse-game-guard.service \
  --property MainPID --value)"
readlink -f "/proc/$guard_pid"/fd/* | grep '/dev/input/event'
```

## Failure Recovery and Removal

If the guard is stopped unexpectedly while it owns mapper restoration state:

```bash
controller-mouse-game-guard --once
systemctl --user start controller-mouse.service
```

To remove the integration:

```bash
systemctl --user disable --now controller-mouse-game-guard.service
systemctl --user disable --now controller-mouse.service
rm -f "$HOME/.config/systemd/user/controller-mouse-game-guard.service"
rm -f "$HOME/.config/systemd/user/controller-mouse.service"
rm -f "$HOME/.config/antimicrox/desktop.gamecontroller.amgp"
rm -f "$HOME/.local/bin/controller-mouse-game-guard"
rm -f "$HOME/.local/bin/controller-mouse-toggle"
rm -f "$HOME/.local/bin/game-with-controller"
systemctl --user daemon-reload
```

Also remove `prefix_command` from `~/.config/lutris/system.yml`.

The kernel patch, USB mode-enforcement service, and optional RT suppression are
not changed by installing or removing this desktop isolation layer.
