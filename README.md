# linux-zhixu-controller-fix

Linux `xpad` workaround for a ZhiXu Xbox 360 clone controller that spoofs
Microsoft's wired Xbox 360 controller USB ID.

## Device

Tested device:

```text
Xbox mode USB vendor:    045e
Xbox mode USB product:   028e
Xbox mode manufacturer:  ZhiXu
Xbox mode product:       Controller
Xbox mode driver:        xpad
```

The same physical controller can also appear as `0079:181c` (`ZhiXu Gamepad`,
DragonRise HID mode). In that mode it is handled by `hid-generic`, bypasses
this `xpad` patch, and can expose the physical D-pad and left stick inverted to
games. On the tested machine, adding `usbcore.quirks=057e:2009:ik` to the
kernel command line and replugging the controller made it enumerate back as
`045e:028e`, where this `xpad` patch applies.

## Tested Machine Circumstance

The laptop touchpad on the tested machine is physically broken or otherwise
non-functional. The ZhiXu controller is therefore also used as a desktop
pointing device through an included AntiMicroX profile. That desktop mapping is
an accessibility/workaround layer, not part of the kernel driver fix.

Games must see the patched real controller but must not see AntiMicroX's
additional virtual keyboard and mouse devices. The optional game guard included
in this repository enforces that separation for Steam and Lutris.

## Symptoms Fixed

On the tested controller, Linux initially treated the physical left stick as
D-pad/hat input. In Wine/Proton games this caused wrong in-game behavior:

- GTA IV: left stick changed radio stations or opened the phone instead of
  steering/moving.
- Max Payne 3: D-pad Up did not work for taking painkillers after preserving
  the left-stick fix.

This patch keeps the working left-stick behavior and restores D-pad Up, Down,
and Right on the tested unit. D-pad Left did not emit raw USB input on the
tested controller, so that appears to be a hardware/controller-firmware issue
on that unit rather than an `xpad` mapping issue.

Later testing in eFootball found a separate issue: the raw Xbox-mode packet
byte that stock `xpad` treats as the right trigger (`RT` / `ABS_RZ`) alternated
between `0x00` and `0xff` while the controller was idle. After an intentional
`RT` press, the same byte could remain stuck at the raw value seen while
pressed even after the trigger was released. Games interpreted this as repeated
or latched full `RT`, causing unintended dash-dribble behavior.

This patch also adds an optional same-device `zhixu_suppress_rt` module
parameter for the eFootball phantom-RT issue. See
`docs/efootball-phantom-rt.md` for the runtime helper and tradeoffs.

## Contents

```text
antimicrox/desktop.gamecontroller.amgp
  Tested AntiMicroX desktop mouse/keyboard profile used because the laptop
  touchpad is not functional.

src/xpad.c
  Full patched xpad.c from xpad-dkms-git r127.9caad15.

patches/0001-zhixu-045e-028e-controller-fix.patch
  Unified diff from the pre-fix xpad.c source to the patched source.

docs/investigation-report.md
  Sanitized investigation log with command history, evidence, and rollback
  notes.

docs/efootball-phantom-rt.md
  Focused explanation and usage notes for the optional eFootball runtime
  workaround.

docs/desktop-controller-mapping.md
  Optional isolation layer for using the real controller as a desktop mouse
  without exposing the virtual mouse/keyboard devices to Steam or Lutris games.

scripts/apply-to-xpad-dkms-source.sh
  Helper script to copy src/xpad.c into an installed xpad-dkms-git source tree.

scripts/controller-mouse-game-guard
  User-session guard that suspends a controller-to-mouse mapper while Steam or
  explicitly wrapped games run.

scripts/controller-mouse-toggle.sh
  Manual desktop-mapper toggle with a desktop notification.

scripts/game-with-controller.sh
  Command wrapper used by Lutris to inhibit the desktop mapper before a game
  process starts.

scripts/zhixu-controller-ensure-xpad-mode.sh
  Boot-time helper that re-authorizes the controller only if it appears as
  `0079:181c` HID/DragonRise mode.

tools/zhixu-rt-raw-probe.sh
  Raw usbmon capture helper used to compare idle, physical-RT-held, and
  released windows during the eFootball investigation.

tools/zhixu-rt-suppress-run.c
  Foreground helper that enables `zhixu_suppress_rt` while it runs and restores
  the previous value when stopped.

systemd/zhixu-controller-ensure-xpad-mode.service
  Optional systemd unit for running the boot-time helper before the display
  manager starts.

systemd/controller-mouse-game-guard.service
  Optional user unit for automatically separating a desktop AntiMicroX mapper
  from Steam and Lutris games.

systemd/controller-mouse.service
  User unit that loads the included AntiMicroX desktop profile.

udev/99-zhixu-controller-xpad-mode.rules
  Optional udev rule that triggers the helper whenever the controller appears
  in `0079:181c` HID/DragonRise mode.
```

## Installation Notes

This is not a packaged driver. It is a source-level workaround intended for
users already using `xpad-dkms-git` or a similar DKMS source tree.

Default source path used during testing:

```text
/usr/src/xpad-r127.9caad15/xpad.c
```

Apply the patched file:

```bash
sudo ./scripts/apply-to-xpad-dkms-source.sh
```

Then rebuild and reload the DKMS module for your installed kernels. Example
from the tested machine:

```bash
sudo dkms build --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms install --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms build --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
sudo dkms install --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
sudo modprobe -r xpad
sudo modprobe xpad
sudo mkinitcpio -P
```

Adjust kernel versions and module version for your system.

### Same-device RT suppression

Build the run-while-active helper:

```bash
make
```

Run it while playing games affected by phantom `RT`:

```bash
sudo ./bin/zhixu-rt-suppress-run
```

While the helper runs, it sets `/sys/module/xpad/parameters/zhixu_suppress_rt`
to `Y`. Stop it with `Ctrl+C`; it restores the previous value before exiting.
The controller remains the real `Microsoft X-Box 360 pad` on the original
`event`/`js` nodes. `ABS_RZ` remains at `0` only while the helper has the
option enabled.

### Multi-mode controller quirk

If the controller appears as `0079:181c DragonRise Inc. Gamepad` / `ZhiXu
Gamepad`, the `xpad` patch is not active. The tested system was fixed by adding
this kernel parameter:

```text
usbcore.quirks=057e:2009:ik
```

On the tested Limine setup, this was added to `/etc/default/limine`:

```bash
KERNEL_CMDLINE[default]+="... usbcore.quirks=057e:2009:ik"
sudo limine-update
```

After a physical unplug/replug, the controller reappeared as `045e:028e` and
bound to `xpad`.

On the tested machine, a reboot could still leave the already-plugged
controller in `0079:181c` until it was unplugged and replugged once. The kernel
parameter was present, but the cold-boot USB enumeration still used HID mode.
To automate the post-boot re-enumeration, install and enable the helper:

```bash
sudo install -Dm755 scripts/zhixu-controller-ensure-xpad-mode.sh /usr/local/sbin/zhixu-controller-ensure-xpad-mode
sudo install -Dm644 systemd/zhixu-controller-ensure-xpad-mode.service /etc/systemd/system/zhixu-controller-ensure-xpad-mode.service
sudo install -Dm644 udev/99-zhixu-controller-xpad-mode.rules /etc/udev/rules.d/99-zhixu-controller-xpad-mode.rules
sudo systemctl daemon-reload
sudo udevadm control --reload
sudo systemctl enable zhixu-controller-ensure-xpad-mode.service
```

The service does nothing when the controller is already `045e:028e`. If it sees
`0079:181c` with manufacturer `ZhiXu`, it de-authorizes and re-authorizes that
USB device so it can enumerate again after `usbcore.quirks=057e:2009:ik` is
active. The udev rule makes the same helper run whenever the bad HID identity
appears later.

Rollback:

```bash
sudo systemctl disable --now zhixu-controller-ensure-xpad-mode.service
sudo rm -f /etc/systemd/system/zhixu-controller-ensure-xpad-mode.service
sudo rm -f /usr/local/sbin/zhixu-controller-ensure-xpad-mode
sudo rm -f /etc/udev/rules.d/99-zhixu-controller-xpad-mode.rules
sudo systemctl daemon-reload
sudo udevadm control --reload
```

### Broken-touchpad desktop mouse and game isolation

The patched `xpad` device and a desktop controller-to-mouse mapper serve
different purposes:

- the patched real `Microsoft X-Box 360 pad` must remain visible to games;
- the included AntiMicroX profile replaces the non-functional laptop touchpad
  for desktop navigation;
- AntiMicroX virtual keyboard/mouse devices can cause duplicate or mixed input
  inside games and must be removed from the game environment.

The repository includes the tested profile, its `controller-mouse.service`,
manual toggle, and the isolation guard. The guard stops only the user mapper
service while a Steam or Lutris game runs. It does not unload `xpad`, grab the
real controller, change `zhixu_suppress_rt`, or require root privileges. Steam
games are detected from their `app-steam-app*.scope` systemd units. Lutris
games use a synchronous command prefix, ensuring the mapper stops before the
game process starts. Because the tested clone re-enumerates when its final
evdev reader closes, the persistent guard keeps one non-exclusive read-only
descriptor open; games can still read the same real controller normally.

Installation, Lutris configuration, runtime behavior, verification, and
rollback are documented in
[`docs/desktop-controller-mapping.md`](docs/desktop-controller-mapping.md).

## Verification

Use `evtest`:

```bash
evtest /dev/input/by-id/usb-ZhiXu_Controller-event-joystick
```

If `/dev/input/by-id` is not present, use the controller event node shown under
`/sys/class/input/event*/device/name`. On the tested machine this was often:

```bash
evtest /dev/input/event17
```

Expected behavior on the tested controller:

- physical left stick reports `ABS_X` / `ABS_Y`
- physical D-pad Up/Down reports `ABS_HAT0Y`
- physical D-pad Right reports `ABS_HAT0X`
- diagonals are possible as simultaneous `ABS_X` and `ABS_Y`, but this clone
  reports digital full-scale endpoints rather than smooth analog values
- force feedback is not exposed for this clone

## License

`src/xpad.c` is derived from the Linux `xpad` driver and keeps its original
SPDX license: `GPL-2.0-or-later`.
