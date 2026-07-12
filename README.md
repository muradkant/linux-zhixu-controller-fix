# Linux ZhiXu controller fix

A device-scoped `xpad` patch for one ZhiXu Xbox 360 clone that impersonates
Microsoft's `045e:028e` wired controller.

```text
USB ID       045e:028e
Manufacturer ZhiXu
Product      Controller
Driver       xpad
```

On the tested unit, the physical left stick arrived as D-pad bits, the physical
D-pad arrived in the nominal left-stick bytes, and ordinary LED/rumble output
could destabilize USB. The patch:

- identifies only `045e:028e` with manufacturer `ZhiXu`;
- maps the clone's D-pad bits to `ABS_X` / `ABS_Y`;
- maps its old analog bytes to `ABS_HAT0X` / `ABS_HAT0Y`;
- disables LED and force-feedback output for this clone; and
- offers opt-in suppression for its unreliable right-trigger byte.

This fixed GTA IV movement and restored Max Payne 3's D-pad Up, Down, and Right
on the tested controller. At one stage D-pad Left emitted no raw USB signal at
all; later Xbox-mode capture did report it. Treat every result here as specific
to this hardware revision and verify your own unit at the Linux input layer.

## Before installing

This is not a packaged driver. `src/xpad.c` is a complete patched copy of
`xpad-dkms-git` revision `r127.9caad15`; the helper replaces that revision's
DKMS source. Do not copy it over an unrelated `xpad` version.

Install the matching DKMS package and kernel headers first. On Arch-family
systems the tested package was AUR `xpad-dkms-git 1:r127.9caad15-1`.

```sh
git clone https://github.com/muradkant/linux-zhixu-controller-fix.git
cd linux-zhixu-controller-fix
sudo ./scripts/apply-to-xpad-dkms-source.sh
```

The script backs up the installed source beside it before replacement. If your
path differs from `/usr/src/xpad-r127.9caad15/xpad.c`, pass it explicitly.

Rebuild—not merely reinstall—the module for each kernel, then reload it. For
example:

```sh
kernel=$(uname -r)
sudo dkms build --force xpad/r127.9caad15 -k "$kernel"
sudo dkms install --force xpad/r127.9caad15 -k "$kernel"
sudo modprobe -r xpad
sudo modprobe xpad
```

Repeat the two DKMS commands for every installed kernel and regenerate that
distribution's initramfs. A running game may retain the old input device;
restart it after reloading the module.

## Verify the driver

Confirm identity and module selection:

```sh
lsusb -d 045e:028e
modinfo -F filename xpad
dkms status xpad
evtest /dev/input/by-id/usb-ZhiXu_Controller-event-joystick
```

Expected on this unit:

- left stick → `ABS_X` / `ABS_Y` (digital full-scale endpoints);
- D-pad → `ABS_HAT0X` / `ABS_HAT0Y`;
- diagonal stick movement → simultaneous X and Y;
- no force-feedback capability.

The stable by-id path is preferable to an `eventN` number, which changes after
re-enumeration.

## Alternate HID mode

The same hardware can enumerate as `0079:181c`, product `ZhiXu Gamepad`, under
`hid-generic`. That mode bypasses this patch and can swap the effective stick
and D-pad. On the tested machine, this kernel argument made a fresh connection
choose Xbox mode:

```text
usbcore.quirks=057e:2009:ik
```

Add it with your bootloader's supported method, reboot or replug, then verify
`045e:028e` with `lsusb`. A controller already connected during cold boot could
still choose HID mode; the included service safely re-authorizes only the
matching ZhiXu device:

```sh
sudo install -Dm755 scripts/zhixu-controller-ensure-xpad-mode.sh \
  /usr/local/sbin/zhixu-controller-ensure-xpad-mode
sudo install -Dm644 systemd/zhixu-controller-ensure-xpad-mode.service \
  /etc/systemd/system/zhixu-controller-ensure-xpad-mode.service
sudo install -Dm644 udev/99-zhixu-controller-xpad-mode.rules \
  /etc/udev/rules.d/99-zhixu-controller-xpad-mode.rules
sudo systemctl daemon-reload
sudo udevadm control --reload
sudo systemctl enable --now zhixu-controller-ensure-xpad-mode.service
```

It exits untouched when `045e:028e` is already present. If it sees ZhiXu
`0079:181c`, it de-authorizes, re-authorizes, and checks for Xbox mode.
The boot unit orders after udev coldplug is triggered but never waits for the
deprecated global `systemd-udev-settle.service`; the matching udev rule invokes
the same idempotent helper for devices that finish later or are hotplugged.

## Phantom right trigger

This clone's nominal `RT` byte alternated between released and fully pressed at
idle, then sometimes stayed latched after a real press. eFootball interpreted
that as repeated dash dribble. Because no stable replacement signal appeared
in raw captures, the optional workaround disables `RT` rather than pretending
to recover it.

```sh
make
sudo ./bin/zhixu-rt-suppress-run
```

The helper sets `zhixu_suppress_rt=Y` only while it runs and restores the prior
value on normal termination. `SIGKILL` cannot run that restoration. See
[Phantom RT](docs/efootball-phantom-rt.md) for manual control and evidence.

## Controller as desktop mouse

The tested laptop has no working touchpad, so the same controller drives an
included AntiMicroX desktop profile. Games must retain the real `xpad` device
without inheriting AntiMicroX's virtual mouse and keyboard. The optional game
guard stops only that user mapper while Steam, Lutris, RetroPort, or another
integrated launcher owns an inhibitor; overlapping games compose safely.

[Desktop mapping and game isolation](docs/desktop-controller-mapping.md)
contains the architecture, exact installation, launcher integration, runtime
state, verification, and removal.

## Repository map

| Path | Purpose |
| --- | --- |
| `src/xpad.c` | Complete patched driver source |
| `patches/0001-…patch` | Diff from the matching upstream source |
| `scripts/apply-to-xpad-dkms-source.sh` | Backup and source replacement |
| `tools/zhixu-rt-raw-probe.sh` | Timed raw USB capture |
| `tools/zhixu-rt-suppress-run.c` | Scoped RT-suppression helper |
| `scripts/zhixu-controller-ensure-xpad-mode.sh` | HID-to-Xbox re-enumeration |
| `antimicrox/`, `scripts/controller-mouse-*`, `systemd/controller-mouse*` | Desktop mapper and game guard |
| `docs/investigation-report.md` | Evidence, rejected hypotheses, state changes, rollback |

## Roll back

Restore only the source patch, rebuild each kernel, and reload:

```sh
target=/usr/src/xpad-r127.9caad15/xpad.c
sudo cp -a "$target.before-linux-zhixu-controller-fix" "$target"
kernel=$(uname -r)
sudo dkms build --force xpad/r127.9caad15 -k "$kernel"
sudo dkms install --force xpad/r127.9caad15 -k "$kernel"
sudo modprobe -r xpad
sudo modprobe xpad
```

Or remove `xpad-dkms-git` through the package manager and regenerate initramfs.
To remove mode enforcement:

```sh
sudo systemctl disable --now zhixu-controller-ensure-xpad-mode.service
sudo rm -f /etc/systemd/system/zhixu-controller-ensure-xpad-mode.service \
  /usr/local/sbin/zhixu-controller-ensure-xpad-mode \
  /etc/udev/rules.d/99-zhixu-controller-xpad-mode.rules
sudo systemctl daemon-reload
sudo udevadm control --reload
```

Remove `usbcore.quirks=057e:2009:ik` through the bootloader and regenerate its
configuration separately.

## Licence

`src/xpad.c` derives from Linux `xpad` and retains `GPL-2.0-or-later`.
