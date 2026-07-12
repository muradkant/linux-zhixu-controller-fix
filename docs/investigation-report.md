# ZhiXu `xpad` investigation

Investigation began 2026-05-15 (Asia/Amman); phantom-RT work followed on
2026-06-27. This report preserves the evidence that changed the diagnosis, the
machine state deliberately changed, and the route back. It omits transient
PIDs, event numbers, and repeated samples that added no new inference.

## Baseline

The controller identified as manufacturer `ZhiXu`, product `Controller`, while
spoofing Microsoft's wired Xbox 360 ID `045e:028e`. The machine ran CachyOS
kernels `7.0.5-2-cachyos` and `6.18.28-1-cachyos-lts`; DKMS 3.4.0 was already
installed, but no external `xpad` package was.

AUR `xpad-dkms-git 1:r127.9caad15-1` supplied the candidate source from
[`paroj/xpad`](https://github.com/paroj/xpad). Its clone startup path recognized
manufacturer `shanwan`, not `ZhiXu`.

## What the failed patches taught

| Revision | Hypothesis | Evidence | Verdict |
| --- | --- | --- | --- |
| Stock DKMS | Newer `xpad` alone might stabilize the clone | repeated USB disconnects and `usb_submit_urb` `-19` | rejected |
| v1 | Send the existing ShanWan startup sequence to `ZhiXu` | brief idle stability, then reconnects; GTA IV stick opened phone/changed radio | rejected |
| v2 | Remap D-pad bits to stick axes; suppress LED and force feedback | `evtest` showed `ABS_X/Y`, no `EV_FF`; GTA IV movement worked | mapping confirmed, D-pad incomplete |
| v3 | Preserve v2; map old analog bytes back to hat axes | D-pad Up/Down/Right appeared as hat events; Max Payne 3 painkiller worked | retained |

The important correction is methodological: a stable input node at idle did
not prove the first patch. The game path falsified it. Each later driver reload
also required the game to reopen the new device before in-game evidence counted.

## Mapping evidence

Before v2, moving the physical left stick emitted only:

```text
ABS_HAT0X ±1
ABS_HAT0Y ±1
```

That fully explained GTA IV's radio and phone actions: Linux itself described
movement as D-pad input. V2 translated those bits to full-scale `ABS_X/Y` and
stopped the clone's nominal analog bytes from overwriting them.

Max Payne 3 then exposed the inverse half of the report layout: physical D-pad
Up produced raw `ff7f` in the nominal left-stick Y bytes but no Linux event. V3
thresholded those old X/Y words at 16000 and reported `ABS_HAT0X/Y`, while
keeping the new stick axes.

One focused capture initially found no raw D-pad Left signal, so no driver could
map it. A later Xbox-mode capture did emit Left correctly. This inconsistency is
why the README promises only the behavior observed per test, not a universal
hardware property.

## USB output and stability

During early GTA IV tests the controller rapidly disconnected and reappeared;
`xpad_try_sending_next_out_packet` then logged `usb_submit_urb` result `-19`
(device gone). That did not prove the output URB caused removal, but it made
clone-unsafe output paths suspect. V2 and later therefore skip LED and
force-feedback registration only when all three match:

```text
vendor       045e
product      028e
manufacturer ZhiXu
```

After a forced DKMS rebuild, `evtest` no longer advertised `EV_FF`. A plain
`dkms install --force` had once reused an old build artifact; the absence of the
`ZhiXu` string in the installed module revealed the mistake. Source changes
must use both commands:

```sh
sudo dkms build --force xpad/r127.9caad15 -k KERNEL
sudo dkms install --force xpad/r127.9caad15 -k KERNEL
```

## Two identities, two drivers

The later “swapped controls” regression was not a failure of v3. `lsusb` showed
the physical device had changed identity:

| Mode | USB ID / product | Driver | Patch active |
| --- | --- | --- | --- |
| Xbox-compatible | `045e:028e` / `Controller` | `xpad` | Yes |
| HID/DragonRise | `0079:181c` / `ZhiXu Gamepad` | `hid-generic` | No |

Unbinding `usbhid` did not change modes. Writing `057e:2009:ik` to usbcore's
quirks and physically reconnecting did: the device returned as `045e:028e`,
bound to `xpad`, exposed no force feedback, and mapped stick and D-pad
correctly. The quirk was then added to Limine's kernel command line and both
boot entries regenerated.

A cold boot with the controller already attached could still enumerate it as
HID even though `/proc/cmdline` and usbcore contained the quirk. Replugging
fixed the running game immediately. That distinguished boot-parameter
persistence from device timing and led to the re-authorization service:

```text
045e:028e ZhiXu present → do nothing
0079:181c ZhiXu present → authorized=0, authorized=1, wait for 045e:028e
```

The udev rule requests the same oneshot service whenever the bad identity
appears after boot.

## Phantom `RT`

In eFootball, moving only the left stick produced repeated `ABS_RZ 255/0`,
which the game's own controls identify as dash dribble (`LS + RT`). Raw usbmon
capture reproduced the fault below Wine:

```text
idle packet A  00140000 00000000 00000000 00000000 00000000
idle packet B  00140000 00ff0000 00000000 00000000 00000000
```

The nominal RT byte alternated at idle. During a physical press it still
alternated; after release it could remain latched. No other byte supplied a
stable press/release distinction. A debounce/inversion attempt could preserve
one press but could not infer the release and was rejected.

A uinput proxy was also rejected: it had to grab the real device, and the
already-running game treated that as controller removal rather than switching
to the virtual device.

The retained solution is explicit loss, not fabricated signal:
`zhixu_suppress_rt=1` forces this clone's `ABS_RZ` to released. It defaults off;
the foreground helper enables it for one game session and restores the prior
value on a handleable exit. While enabled, every other mapping survives but RT
does not.

## Deliberate machine changes

The investigation installed:

- `xpad-dkms-git 1:r127.9caad15-1`;
- diagnostic packages `evtest` and `linuxconsole`;
- patched DKMS builds for the two tested kernels;
- `usbcore.quirks=057e:2009:ik` in the Limine kernel command line;
- the mode-enforcement script, systemd service, and udev rule; and
- later, the desktop-mapper user services documented separately.

The source was backed up before each experimental replacement. The repository's
final `src/xpad.c` is the authoritative retained version; its SHA-256 at this
rewrite is:

```text
1a287555d6f18d09ea3e836f9d07ab2b84b8fb70d146c7b2d51c37a71f7eccd1
```

The tested `srcversion` identifiers were `CEAD709E5ECB5E157C30969` for v2 and
`D8FA079063ECC1F81AE5CE9` for v3. These identify the historical builds, not a
portable trust root; build from the repository and verify behavior.

## Reconstruction and verification

Install the repository source, rebuild every kernel, reload, and refresh boot
artifacts as described in the README. Then prove each boundary independently:

```sh
lsusb -d 045e:028e
modinfo -F filename -F srcversion xpad
dkms status xpad
evtest /dev/input/by-id/usb-ZhiXu_Controller-event-joystick
```

Evidence required:

1. identity is `045e:028e` with manufacturer `ZhiXu`;
2. `modinfo` resolves the DKMS module under `updates/dkms`;
3. stick emits `ABS_X/Y`, D-pad emits `ABS_HAT0X/Y`, and `EV_FF` is absent;
4. a freshly launched game consumes those current mappings;
5. kernel logs show no spontaneous reconnect loop during that game.

For the RT fault, `tools/zhixu-rt-raw-probe.sh` captures timed idle, held, and
released windows directly from usbmon. With suppression active, `evtest` should
show initial `ABS_RZ 0` and no idle RT transitions.

The mode helper itself was checked with `sh -n`; `udevadm test` loaded the rule
without invalid-key warnings. In an already-good state, the service exited
successfully with “already in Xbox/xpad mode.” A true cold-boot failure remains
verifiable only by booting attached hardware and observing the resulting USB
identity.

## Rollback

Remove the DKMS package entirely:

```sh
sudo pacman -Rns xpad-dkms-git
sudo mkinitcpio -P
```

Or restore the helper's pre-install source backup and rebuild each kernel:

```sh
target=/usr/src/xpad-r127.9caad15/xpad.c
sudo cp -a "$target.before-linux-zhixu-controller-fix" "$target"
sudo dkms build --force xpad/r127.9caad15 -k KERNEL
sudo dkms install --force xpad/r127.9caad15 -k KERNEL
sudo modprobe -r xpad
sudo modprobe xpad
```

Remove mode enforcement:

```sh
sudo systemctl disable --now zhixu-controller-ensure-xpad-mode.service
sudo rm -f /etc/systemd/system/zhixu-controller-ensure-xpad-mode.service \
  /usr/local/sbin/zhixu-controller-ensure-xpad-mode \
  /etc/udev/rules.d/99-zhixu-controller-xpad-mode.rules
sudo systemctl daemon-reload
sudo udevadm control --reload
```

Finally remove `usbcore.quirks=057e:2009:ik` from the bootloader configuration
and regenerate it. Diagnostic packages can be removed independently with
`sudo pacman -Rns evtest linuxconsole`. Snapper created root snapshots 33–36
around the earliest package work; inspect rather than restore them blindly.
