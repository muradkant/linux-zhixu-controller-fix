# xpad-dkms-git Controller Investigation Report

Date started: 2026-05-15 00:03 Asia/Amman

Purpose: try the first-ranked technical option for the unstable wired Xbox 360-compatible controller: replace the in-kernel `xpad` path with the AUR `xpad-dkms-git` driver, then document every committed change so it can be reversed.

## Baseline Before Changes

- Running kernel at start of work: `7.0.5-2-cachyos`
- Installed kernels/headers observed:
  - `linux-cachyos 7.0.5-2`
  - `linux-cachyos-headers 7.0.5-2`
  - `linux-cachyos-lts 6.18.28-1`
  - `linux-cachyos-lts-headers 6.18.28-1`
- DKMS already installed before this work: `dkms 3.4.0-2`
- Existing xpad-related packages before this work:
  - No `xpad-dkms-git`
  - No `xpad-noone-git`
  - No `xpadneo-dkms`
- Built-in kernel module before this work:
  - `/lib/modules/7.0.5-2-cachyos/kernel/drivers/input/joystick/xpad.ko.zst`
  - `/lib/modules/6.18.28-1-cachyos-lts/kernel/drivers/input/joystick/xpad.ko.zst`

## AUR Candidate Found

Command used:

```bash
paru -Ss xpad
```

Relevant candidate:

```text
aur/xpad-dkms-git 1:r127.9caad15-1
    Driver for the Xbox/ Xbox 360/ Xbox 360 Wireless/ Xbox One Controllers
```

## Committed Steps

### 1. Installed `xpad-dkms-git`

Approximate time: 2026-05-15 00:05 Asia/Amman

Command used:

```bash
paru -S --needed xpad-dkms-git
```

Interactive answers given:

```text
Proceed to review? Y
Accept changes? Y
sudo password entered when prompted
```

Package installed:

```text
xpad-dkms-git 1:r127.9caad15-1
```

Important package details reviewed before install:

```text
url='https://github.com/paroj/xpad'
depends=('dkms')
makedepends=('git')
provides=('xpad-dkms')
conflicts=('xpad-dkms')
source=("$pkgname::git+https://github.com/paroj/xpad.git")
```

Files installed by the AUR package are expected under:

```text
/usr/src/xpad-r127.9caad15/
```

Package hooks performed by pacman/paru:

```text
Snapper pre snapshot: root: 33
DKMS install for 6.18.28-1-cachyos-lts
DKMS install for 7.0.5-2-cachyos
depmod 6.18.28-1-cachyos-lts
depmod 7.0.5-2-cachyos
Updated initramfs for linux-cachyos-lts
Updated initramfs for linux-cachyos
Updated /boot/limine.conf
Snapper post snapshot: root: 34
```

Source inspection note:

The `paroj/xpad` source includes an Xbox 360 startup sequence for some fake/clone controllers that identify as `045e:028e`. In the unmodified source, that automatic manufacturer-string path checks for `shanwan`, not `ZhiXu`, so this unmodified install is a clean first attempt but may not target this exact clone.

### 2. Reloaded `xpad` for the active session

Approximate time: 2026-05-15 00:08 Asia/Amman

Reason: `xpad` was already loaded before `xpad-dkms-git` was installed. Reloading it forces the running session to use the module path selected by `modinfo`, which now points at the DKMS module.

Commands used:

```bash
sudo modprobe -r xpad
sudo modprobe xpad
```

This is an active-session change only. It does not create a persistent config file. A reboot would also reload the module.

### 3. Backed up DKMS source before local `ZhiXu` patch

Approximate time: 2026-05-15 00:15 Asia/Amman

Command used:

```bash
sudo cp -a /usr/src/xpad-r127.9caad15/xpad.c /usr/src/xpad-r127.9caad15/xpad.c.before-zhixu-patch
```

Backup file created:

```text
/usr/src/xpad-r127.9caad15/xpad.c.before-zhixu-patch
```

This backup is a byte-for-byte copy of the DKMS source file before local patching.

### 4. Patched DKMS source to include `ZhiXu`

Approximate time: 2026-05-15 00:16 Asia/Amman

File changed:

```text
/usr/src/xpad-r127.9caad15/xpad.c
```

Command used:

```bash
sudo perl -0pi -e 's/bool is_shanwan = xpad->udev->manufacturer && strcasecmp\("shanwan", xpad->udev->manufacturer\) == 0;/bool is_shanwan = xpad->udev->manufacturer &&\n\t\t(strcasecmp("shanwan", xpad->udev->manufacturer) == 0 ||\n\t\t strcasecmp("ZhiXu", xpad->udev->manufacturer) == 0);/' /usr/src/xpad-r127.9caad15/xpad.c
```

Diff:

```diff
-	bool is_shanwan = xpad->udev->manufacturer && strcasecmp("shanwan", xpad->udev->manufacturer) == 0;
+	bool is_shanwan = xpad->udev->manufacturer &&
+		(strcasecmp("shanwan", xpad->udev->manufacturer) == 0 ||
+		 strcasecmp("ZhiXu", xpad->udev->manufacturer) == 0);
```

Reason: the controller reports manufacturer string `ZhiXu` while spoofing `045e:028e`. The upstream/paroj code already applies a fake-controller Xbox 360 startup sequence to manufacturer `shanwan`; this local patch makes `ZhiXu` use that same sequence.

### 5. Rebuilt/reinstalled patched DKMS module for both kernels

Approximate time: 2026-05-15 00:17 Asia/Amman

Commands used:

```bash
sudo dkms install --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms install --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
```

Observed behavior for each kernel:

```text
Before uninstall, this module version was ACTIVE on this kernel.
Deleting .../updates/dkms/xpad.ko.zst
Restoring archived original module .../kernel/drivers/input/joystick/xpad.ko.zst
Running depmod... done.
Found pre-existing .../kernel/drivers/input/joystick/xpad.ko.zst, archiving for uninstallation
Installing .../updates/dkms/xpad.ko.zst
Running depmod... done.
```

Interpretation: the patched source was compiled and installed into each kernel's `updates/dkms` module path.

### 6. Reloaded patched `xpad` for the active session

Approximate time: 2026-05-15 00:18 Asia/Amman

Commands used:

```bash
sudo modprobe -r xpad
sudo modprobe xpad
```

Reason: rebuilding DKMS changes the module file on disk, but the already-loaded kernel module must be unloaded and loaded again before the current boot uses the patched build.

### 7. Rebuilt initramfs and updated Limine boot entries

Approximate time: 2026-05-15 00:20 Asia/Amman

Command used:

```bash
sudo mkinitcpio -P
```

Interactive answer:

```text
Would you like to run 'limine-mkinitcpio' now? Y
```

Observed results:

```text
Initcpio image generation successful for linux-cachyos-lts
Initcpio image generation successful for linux-cachyos
Kernel stored in /boot/5c96314f272e4a58b63e802ce99dbb0b/linux-cachyos-lts/vmlinuz-linux-cachyos-lts
Initramfs stored in /boot/5c96314f272e4a58b63e802ce99dbb0b/linux-cachyos-lts/initramfs-linux-cachyos-lts
Kernel stored in /boot/5c96314f272e4a58b63e802ce99dbb0b/linux-cachyos/vmlinuz-linux-cachyos
Initramfs stored in /boot/5c96314f272e4a58b63e802ce99dbb0b/linux-cachyos/initramfs-linux-cachyos
Updated: /boot/limine.conf
```

Reason: DKMS rebuilds the module on disk, but rebuilding initramfs/boot entries ensures the patched module state is reflected in boot artifacts as well.

## Verification After Local `ZhiXu` Patch

### Initial stability sample

Approximate time: 2026-05-15 00:18 Asia/Amman

Commands used:

```bash
journalctl -k -b --since '2026-05-15 00:17:45' -g 'xpad|usb 1-3|Microsoft X-Box 360|ZhiXu' --no-pager
ls -l /sys/class/input/js0 /sys/class/input/event17
sed -n '1p' /sys/class/input/js0/device/name /sys/class/input/js0/device/phys
```

Observed results:

```text
-- No entries --
/sys/class/input/event17 -> .../input/input811/event17
/sys/class/input/js0 -> .../input/input811/js0
Microsoft X-Box 360 pad
```

Interpretation: after the patched `xpad` reload, there were no fresh kernel log entries matching the previous reconnect/error pattern in the sampled window, and the input node remained stable as `input811`.

### Longer stability sample

Approximate time: 2026-05-15 00:19 Asia/Amman

After waiting roughly 30 seconds, the same checks were repeated.

Observed results:

```text
journalctl ... --since '2026-05-15 00:17:45' ... -> -- No entries --
/sys/class/input/event17 -> .../input/input811/event17
/sys/class/input/js0 -> .../input/input811/js0
```

Interpretation: the patched driver continued to hold a stable input node with no new `usb 1-3`, `ZhiXu`, or `xpad` reconnect/error entries during the longer sample window.

### Final audit

Approximate time: 2026-05-15 00:21 Asia/Amman

Checklist:

```text
Requirement: patch the driver.
Evidence: /usr/src/xpad-r127.9caad15/xpad.c differs from /usr/src/xpad-r127.9caad15/xpad.c.before-zhixu-patch only by adding manufacturer string "ZhiXu" to the existing fake-controller startup sequence condition.

Requirement: compile/install the patched driver.
Evidence: dkms status reports xpad/r127.9caad15 installed for both 6.18.28-1-cachyos-lts and 7.0.5-2-cachyos.

Requirement: use the patched driver in the current session.
Evidence: modinfo xpad resolves to /lib/modules/7.0.5-2-cachyos/updates/dkms/xpad.ko.zst and xpad was reloaded after the DKMS rebuild.

Requirement: preserve reversibility documentation.
Evidence: this report documents every committed command and includes rollback commands for removing xpad-dkms-git or undoing only the local ZhiXu source patch.

Requirement: verify the patch addressed the observed reconnect failure.
Evidence: before the patch the log repeatedly showed usb 1-3 reconnects and xpad submit failures. After patched reload, journalctl since 2026-05-15 00:17:45 returned "-- No entries --" for the same xpad/usb/ZhiXu filter, while js0 and event17 remained on input811.
```

Conclusion: the local `ZhiXu` patch is installed, active, documented, and the kernel-level reconnect loop stopped during the observed post-patch windows.

### Regression after in-game test

Approximate time: 2026-05-15 00:28 Asia/Amman

After GTA IV was tested, the prior conclusion was invalidated by later evidence.

Observed symptoms:

```text
In GTA IV, left stick left/right changes radio stations instead of steering.
Moving the left stick upward opens the phone.
```

Observed kernel evidence:

```text
May 15 00:23:21 ... usb 1-3: USB disconnect
May 15 00:23:21 ... xpad 1-3:1.0: xpad_try_sending_next_out_packet - usb_submit_urb failed with result -19
May 15 00:23:21 ... input: Microsoft X-Box 360 pad as ... input/input812
...
May 15 00:23:32 ... input: Microsoft X-Box 360 pad as ... input/input826
```

Current device symlink later observed:

```text
/sys/class/input/event17 -> .../input/input826/event17
/sys/class/input/js0 -> .../input/input826/js0
```

Updated interpretation:

```text
Patch v1 (`ZhiXu` treated like `shanwan`) may briefly suppress reconnects at idle, but it does not survive the game/runtime path. It also does not correct the effective control mapping in GTA IV. Further patches are required.
```

## Follow-up: Stable Device But Wrong Mapping

Reported after in-game test:

```text
GTA IV no longer proves the patch successful. While driving, moving the left stick left/right changes radio stations instead of steering. Moving the left stick upward opens the phone. This means the controller is now stable enough to be seen, but its left stick is still being interpreted like D-pad/navigation input by the game stack.
```

Working hypothesis:

```text
The local ZhiXu patch likely fixed the USB reconnect loop by sending the clone-controller startup sequence, but the resulting input report layout is still not being parsed as normal Xbox 360 axes. The next investigation must distinguish kernel event mapping from Wine/XInput mapping.
```

## Verification After Install

### Package/DKMS state

Commands used:

```bash
pacman -Q xpad-dkms-git
dkms status xpad
modinfo xpad | sed -n '1,20p'
```

Observed results:

```text
xpad-dkms-git 1:r127.9caad15-1
xpad/r127.9caad15, 6.18.28-1-cachyos-lts, x86_64: installed (Original modules exist)
xpad/r127.9caad15, 7.0.5-2-cachyos, x86_64: installed (Original modules exist)
filename: /lib/modules/7.0.5-2-cachyos/updates/dkms/xpad.ko.zst
```

Interpretation: the DKMS `xpad` module is installed and is the `xpad` module selected by `modinfo` for the running kernel.

### Controller behavior after reloading DKMS `xpad`

Commands used:

```bash
journalctl -k -b -g 'xpad|usb 1-3|Microsoft X-Box 360|ZhiXu' --no-pager -n 40
ls -l /sys/class/input/js0 /sys/class/input/event17
```

Observed results:

```text
usb 1-3: Manufacturer: ZhiXu
input: Microsoft X-Box 360 pad as ... input/input594
xpad 1-3:1.0: xpad_try_sending_next_out_packet - usb_submit_urb failed with result -19
usb 1-3: USB disconnect
input node later changed again to input/input601
```

Interpretation: the unmodified `xpad-dkms-git` package did not stabilize this `ZhiXu` clone. The controller is still reconnecting repeatedly after the DKMS module is active.

## Rollback Notes

To remove the installed DKMS package:

```bash
sudo pacman -Rns xpad-dkms-git
```

After removal, rebuild initramfs if the package hooks do not do it automatically:

```bash
sudo mkinitcpio -P
```

To undo only the local `ZhiXu` source patch while keeping `xpad-dkms-git` installed:

```bash
sudo cp -a /usr/src/xpad-r127.9caad15/xpad.c.before-zhixu-patch /usr/src/xpad-r127.9caad15/xpad.c
sudo dkms install --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms install --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
sudo modprobe -r xpad
sudo modprobe xpad
sudo mkinitcpio -P
```

Snapper snapshots created around the install:

```text
pre:  root 33
post: root 34
```

If a full filesystem rollback is preferred, inspect snapshots first:

```bash
sudo snapper -c root list
```

## Follow-up After Patch v1 Failed

### In-game failure

After the first local `ZhiXu` initialization patch, the controller still did not work correctly in GTA IV. The observed in-game behavior was:

```text
left stick left/right -> changes radio stations
left stick up -> opens the phone
```

Interpretation: GTA IV is receiving the movement as D-pad/hat input rather than as the Xbox 360 left analog stick.

### Kernel evidence while GTA IV was running

Command used:

```bash
sudo dmesg -T | tail -180
```

Important observed lines:

```text
[Fri May 15 00:23:20 2026] usb 1-3: USB disconnect, device number 65
[Fri May 15 00:23:20 2026] xpad 1-3:1.0: xpad_try_sending_next_out_packet - usb_submit_urb failed with result -19
[Fri May 15 00:23:21 2026] usb 1-3: new full-speed USB device number 66 using xhci_hcd
[Fri May 15 00:23:21 2026] usb 1-3: Manufacturer: ZhiXu
[Fri May 15 00:23:21 2026] input: Microsoft X-Box 360 pad as ... input/input812
...
[Fri May 15 00:23:31 2026] input: Microsoft X-Box 360 pad as ... input/input826
```

Interpretation: the controller entered a rapid disconnect/reconnect loop. The repeating `xpad_try_sending_next_out_packet ... -19` line means `xpad` tried to submit an output URB after the USB device had already vanished. That does not prove the output packet caused the disconnect, but it strongly implicates output paths such as force feedback or LED writes as unsafe for this clone.

### Diagnostic tools installed

Command used:

```bash
sudo pacman -S --needed --noconfirm evtest linuxconsole
```

Result:

```text
installed evtest 1.36-1.1
installed linuxconsole 1.8.1-1.1
snapper pre snapshot:  root 35
snapper post snapshot: root 36
```

Rollback for the diagnostic tools only:

```bash
sudo pacman -Rns evtest linuxconsole
```

### Host process state

Command used:

```bash
ps -ef | rg -i 'gta|lutris|wine|wineserver|steam'
```

Observed result:

```text
python3 /usr/bin/lutris
lutris-wrapper GTA IV ... /usr/bin/umu-run /mnt/DATA/Grand Theft Auto IV/GTAIV.exe
GE-Proton10-34 ... wine64 ... GTAIV.exe
S:\Grand Theft Auto IV\GTAIV.exe
```

Interpretation: GTA IV was still running under Lutris/GE-Proton during the investigation.

### Input-layer evidence

Command used:

```bash
timeout 12 evtest /dev/input/event17
```

Device identity:

```text
Input device ID: bus 0x3 vendor 0x45e product 0x28e version 0x110
Input device name: "Microsoft X-Box 360 pad"
```

Important supported events:

```text
EV_ABS ABS_X      min -32768 max 32767
EV_ABS ABS_Y      min -32768 max 32767
EV_ABS ABS_HAT0X  min -1 max 1
EV_ABS ABS_HAT0Y  min -1 max 1
EV_FF  FF_RUMBLE
```

Important observed movement events while the left stick was moved:

```text
EV_ABS ABS_HAT0Y value -1
EV_ABS ABS_HAT0X value 1
EV_ABS ABS_HAT0Y value 1
EV_ABS ABS_HAT0X value -1
```

No corresponding `ABS_X` or `ABS_Y` movement was observed during that capture.

Interpretation: this is the exact technical reason GTA IV changes radio/phone instead of steering. The clone is exposing the physical left-stick movement as D-pad hat movement at the Linux input layer.

## Patch v2 Plan

The next patch will remain scoped to this exact clone:

```text
USB vendor:      045e
USB product:     028e
manufacturer:    ZhiXu
reported name:   Microsoft X-Box 360 pad
```

Planned source changes in `/usr/src/xpad-r127.9caad15/xpad.c`:

1. Add helper `xpad_is_zhixu_360_clone()` matching `045e:028e` with manufacturer string `ZhiXu`.
2. Keep the v1 startup/control-message behavior for this clone, but express it through the helper instead of treating all `ZhiXu` text as `shanwan`.
3. In `xpad360_process_packet()`, translate D-pad bit movement from this clone into `ABS_X` and `ABS_Y` reports, and suppress the normal `ABS_HAT0X`/`ABS_HAT0Y` reporting for those same bits.
4. Do not overwrite the translated `ABS_X`/`ABS_Y` values with the clone's zero analog bytes later in packet processing.
5. Skip force-feedback registration for this clone, so Wine/GTA IV should not send rumble packets through `xpad_play_effect()`.
6. Skip LED registration for this clone, so `xpad_led_probe()` does not send LED output packets.

Expected result if patch v2 works:

```text
evtest left-stick movement -> ABS_X / ABS_Y events
evtest device capabilities -> no EV_FF force-feedback capability for this clone
GTA IV left-stick movement -> steering/movement rather than radio/phone
kernel log during test -> no renewed usb 1-3 disconnect loop
```

## Patch v2 Execution

### Source backup and replacement

Commands used:

```bash
cp /usr/src/xpad-r127.9caad15/xpad.c /tmp/xpad.c.zhixu-v2
# edited /tmp/xpad.c.zhixu-v2, then:
sudo cp -a /usr/src/xpad-r127.9caad15/xpad.c /usr/src/xpad-r127.9caad15/xpad.c.before-zhixu-v2
sudo cp -a /tmp/xpad.c.zhixu-v2 /usr/src/xpad-r127.9caad15/xpad.c
```

Checksums after replacement:

```text
21ee457b79fcd74fc490cbd3ad6e53780259187e2c08abfaf549f4f4f36a2c7b  /usr/src/xpad-r127.9caad15/xpad.c
21ee457b79fcd74fc490cbd3ad6e53780259187e2c08abfaf549f4f4f36a2c7b  /tmp/xpad.c.zhixu-v2
7d789fa0e866997688c2d8d8a6e76bad44ffb87c5279be7e476733aa77f12f2c  /usr/src/xpad-r127.9caad15/xpad.c.before-zhixu-v2
```

Rollback to the pre-v2 source only:

```bash
sudo cp -a /usr/src/xpad-r127.9caad15/xpad.c.before-zhixu-v2 /usr/src/xpad-r127.9caad15/xpad.c
sudo dkms build --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms install --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms build --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
sudo dkms install --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
sudo modprobe -r xpad
sudo modprobe xpad
```

### Important DKMS correction

Initially I ran:

```bash
sudo dkms install --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms install --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
```

That did not rebuild from the changed source; it reused the previous built artifact. Evidence:

```bash
zstdcat /lib/modules/7.0.5-2-cachyos/updates/dkms/xpad.ko.zst | strings | rg -n 'ZhiXu'
```

The command returned no `ZhiXu` string at that point, and `evtest` still showed `EV_FF`.

Corrected commands:

```bash
sudo dkms build --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms install --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms build --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
sudo dkms install --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
```

Verification that the rebuilt module contains the new patch:

```bash
zstdcat /lib/modules/7.0.5-2-cachyos/updates/dkms/xpad.ko.zst | strings | rg -n 'ZhiXu|shanwan'
modinfo -F srcversion xpad
```

Observed result:

```text
83:ZhiXu
84:shanwan
CEAD709E5ECB5E157C30969
```

### Reload into the running kernel

Commands used:

```bash
sudo modprobe -r xpad
sudo modprobe xpad
```

Observed result from kernel log:

```text
[Fri May 15 00:38:03 2026] usbcore: deregistering interface driver xpad
[Fri May 15 00:38:03 2026] usb 1-3: USB disconnect, device number 82
[Fri May 15 00:38:04 2026] usb 1-3: new full-speed USB device number 83 using xhci_hcd
[Fri May 15 00:38:04 2026] usb 1-3: Manufacturer: ZhiXu
[Fri May 15 00:38:04 2026] input: Microsoft X-Box 360 pad as ... input/input828
[Fri May 15 00:38:04 2026] usbcore: registered new interface driver xpad
```

Interpretation: the disconnect at `00:38:03` was caused by deliberately unloading/reloading `xpad`. The log did not show the earlier rapid reconnect loop after the rebuilt module was loaded.

### Post-patch input verification

Command used:

```bash
timeout 15 evtest /dev/input/event17
```

Observed capabilities after the rebuilt module was loaded:

```text
EV_ABS ABS_X      min -32768 max 32767
EV_ABS ABS_Y      min -32768 max 32767
EV_ABS ABS_HAT0X  min -1 max 1
EV_ABS ABS_HAT0Y  min -1 max 1
```

Important difference: `EV_FF` was no longer listed by `evtest`, so force feedback was successfully suppressed for this clone.

Observed movement events while the left stick was moved:

```text
EV_ABS ABS_X value -32767
EV_ABS ABS_X value 32767
EV_ABS ABS_Y value -32767
EV_ABS ABS_Y value 32767
```

Interpretation: patch v2 fixed the Linux input-layer problem. The physical left stick now reports as Xbox left-stick axes (`ABS_X`/`ABS_Y`) instead of D-pad hat events (`ABS_HAT0X`/`ABS_HAT0Y`).

Remaining verification needed: GTA IV must be restarted after the driver reload and tested in-game, because the already-running Wine process may still have stale controller state from the pre-v2 device instance.

### Initramfs and Limine refresh

Command used:

```bash
sudo mkinitcpio -P
```

Observed result:

```text
Initcpio image generation successful for linux-cachyos-lts (6.18.28-1-cachyos-lts)
Initcpio image generation successful for linux-cachyos (7.0.5-2-cachyos)
Updated: /boot/limine.conf
```

Interpretation: the boot artifacts were refreshed after the patched DKMS module was rebuilt and installed.

### Pre-game-retest state check

Commands used:

```bash
modinfo -F filename -F srcversion xpad
ps -ef | rg -i 'gta|lutris|wine|wineserver|steam'
ls -la /dev/input/by-id /dev/input/event17 /dev/input/js0
sudo dmesg -T | tail -35
```

Observed result:

```text
xpad srcversion: CEAD709E5ECB5E157C30969
/dev/input/by-id/usb-ZhiXu_Controller-event-joystick -> ../event17
/dev/input/by-id/usb-ZhiXu_Controller-joystick -> ../js0
GTAIV.exe process was still the instance launched at 00:23
last controller re-enumeration after rebuilt module reload: 00:38:04
```

Interpretation: the already-running GTA IV process predates the successful rebuilt driver reload. A valid in-game verification requires fully quitting GTA IV and launching it again from Lutris so Wine opens the current patched controller device.

### Reconnect loop observed during GTA IV relaunch attempt

After GTA IV was stopped and relaunched from Lutris, I captured another kernel-log sample.

Command used:

```bash
sudo dmesg -T | tail -80
```

Observed result:

```text
[Fri May 15 00:41:55 2026] input: Microsoft X-Box 360 pad as ... input/input861
[Fri May 15 00:41:55 2026] usb 1-3: USB disconnect, device number 116
[Fri May 15 00:41:56 2026] input: Microsoft X-Box 360 pad as ... input/input862
[Fri May 15 00:41:56 2026] usb 1-3: USB disconnect, device number 117
[Fri May 15 00:41:57 2026] input: Microsoft X-Box 360 pad as ... input/input863
[Fri May 15 00:41:57 2026] usb 1-3: USB disconnect, device number 118
...
[Fri May 15 00:42:04 2026] input: Microsoft X-Box 360 pad as ... input/input872
```

Interpretation: patch v2 fixed the left-stick Linux event mapping and removed force-feedback exposure, but it did not fully solve the USB stability issue. The reconnect loop returned while GTA IV was being relaunched. Since `EV_FF` was no longer exposed, the next suspect is the remaining `ZhiXu` startup/control-message path in `xpad_start_xbox_360()` or another Wine/open-triggered input path rather than rumble.

Next likely patch direction: test a v3 that keeps the input remapping and FF/LED suppression, but removes the `ZhiXu` clone from the special `shanwan`/GameSir startup control-message sequence.

### Final in-game verification

After GTA IV was relaunched from Lutris using the patched controller device, I
verified that the in-game controller behavior was corrected.

Interpretation: patch v2 is validated by both Linux input-layer verification
and the restarted GTA IV in-game test. The left stick no longer acts as
radio/phone D-pad input in GTA IV.

## Max Payne 3 D-pad Up / Painkiller Follow-up

### New symptom

In Max Payne 3, the v2 patch preserves the important progress from GTA IV: Max moves correctly with the left stick. New issue:

```text
D-pad Up should take a painkiller, but pressing D-pad Up does nothing.
```

Constraint: preserve the working left-stick behavior.

### Current runtime state

Commands used:

```bash
ps -ef | rg -i 'max|payne|lutris|wine|wineserver|steam'
ls -la /dev/input/by-id /dev/input/event17 /dev/input/js0
modinfo -F srcversion xpad
```

Observed result:

```text
MaxPayne3.exe is running under Lutris / GE-Proton
/dev/input/by-id/usb-ZhiXu_Controller-event-joystick -> ../event17
/dev/input/by-id/usb-ZhiXu_Controller-joystick -> ../js0
xpad srcversion: CEAD709E5ECB5E157C30969
```

### First D-pad Up capture

Command used:

```bash
timeout 10 evtest /dev/input/event17
```

Observed result:

```text
Supported events include ABS_X, ABS_Y, ABS_HAT0X, ABS_HAT0Y
No input events were captured during the test window.
```

Interpretation: inconclusive by itself. It either missed the physical press timing, or D-pad Up is not currently generating a Linux event that Wine/Max Payne 3 can consume.

### Input-test confirmation

I verified that D-pad Up was being pressed during the `evtest` window.

Interpretation: treat the lack of `evtest` events as real. Physical D-pad Up is not currently reaching Linux's input layer.

### Raw USB packet capture

Commands used:

```bash
sudo modprobe usbmon
sudo bash -lc "timeout 8 cat /sys/kernel/debug/usb/usbmon/1u" \
  | awk '/C Ii:1:062:1/ { payload=$0; sub(/^.* = /, "", payload); count[payload]++ } END { for (p in count) print count[p], p }' \
  | sort -nr | head -20
```

Observed unique payloads while D-pad Up was pressed:

```text
4014 00140000 00000000 ff7f0000 00000000 00000000
3473 00140000 00000000 00000000 00000000 00000000
```

Interpretation: physical D-pad Up is reported by this clone in the old left-stick analog Y bytes (`ff7f` at bytes 8-9), not in the normal Xbox 360 D-pad bit field. Patch v2 fixed the physical left stick by mapping the normal D-pad bit field to `ABS_X`/`ABS_Y`, but it also stopped reporting the old analog bytes. That preserved GTA IV movement but accidentally hid the physical D-pad from games.

Next patch direction: preserve v2 left-stick mapping, and for the `ZhiXu` clone additionally translate the old analog left-stick bytes into `ABS_HAT0X`/`ABS_HAT0Y` with a threshold. This should restore physical D-pad behavior without disturbing the working left stick.

### Patch v3 plan and source staging

Patch v3 keeps all v2 behavior and adds only this `ZhiXu`-scoped behavior inside `xpad360_process_packet()`:

```text
normal D-pad bit field    -> ABS_X / ABS_Y      (v2 left-stick fix, preserved)
old left-stick analog XY  -> ABS_HAT0X/HAT0Y    (v3 physical D-pad restoration)
```

The threshold is `16000` on the old analog bytes, so centered/noise values remain neutral while full D-pad presses become `-1`, `0`, or `1` hat events.

Commands used:

```bash
cp /usr/src/xpad-r127.9caad15/xpad.c /tmp/xpad.c.zhixu-v3
# edited /tmp/xpad.c.zhixu-v3
sudo cp -a /usr/src/xpad-r127.9caad15/xpad.c /usr/src/xpad-r127.9caad15/xpad.c.before-zhixu-v3
sudo cp -a /tmp/xpad.c.zhixu-v3 /usr/src/xpad-r127.9caad15/xpad.c
```

Checksums:

```text
21ee457b79fcd74fc490cbd3ad6e76bad44ffb87c5279be7e476733aa77f12f2c  /usr/src/xpad-r127.9caad15/xpad.c.before-zhixu-v3
b19133bcfb5feba7a1a39bf35896b46bda3849a7a9eab4425be3d206c390ca0a  /tmp/xpad.c.zhixu-v3
```

Rollback from v3 to v2 source:

```bash
sudo cp -a /usr/src/xpad-r127.9caad15/xpad.c.before-zhixu-v3 /usr/src/xpad-r127.9caad15/xpad.c
sudo dkms build --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms install --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms build --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
sudo dkms install --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
sudo modprobe -r xpad
sudo modprobe xpad
```

### Patch v3 build/install

Commands used:

```bash
sudo dkms build --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms install --force xpad/r127.9caad15 -k 7.0.5-2-cachyos
sudo dkms build --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
sudo dkms install --force xpad/r127.9caad15 -k 6.18.28-1-cachyos-lts
```

Observed result:

```text
xpad/r127.9caad15, 6.18.28-1-cachyos-lts, x86_64: installed
xpad/r127.9caad15, 7.0.5-2-cachyos, x86_64: installed
current source checksum: b19133bcfb5feba7a1a39bf35896b46bda3849a7a9eab4425be3d206c390ca0a
pre-v3 source checksum: 21ee457b79fcd74fc490cbd3ad6e53780259187e2c08abfaf549f4f4f36a2c7b
new module srcversion: D8FA079063ECC1F81AE5CE9
```

Clarification: patch v3 is intended to restore the whole physical D-pad, not only Up. It maps old analog X to `ABS_HAT0X` for Left/Right and old analog Y to `ABS_HAT0Y` for Up/Down while preserving the v2 left-stick mapping.

### Patch v3 reload

Commands used:

```bash
sudo modprobe -r xpad
sudo modprobe xpad
modinfo -F srcversion xpad
```

Observed result:

```text
loaded xpad srcversion: D8FA079063ECC1F81AE5CE9
/dev/input/by-id/usb-ZhiXu_Controller-event-joystick -> ../event17
/dev/input/by-id/usb-ZhiXu_Controller-joystick -> ../js0
```

The reload deliberately disconnected/reconnected the controller.

### Patch v3 Linux input verification

Command used:

```bash
timeout 15 evtest /dev/input/event17
```

Observed events:

```text
D-pad Up:    ABS_HAT0Y value -1, then 0
D-pad Down:  ABS_HAT0Y value  1, then 0
D-pad Right: ABS_HAT0X value  1, then 0
Left stick:  ABS_X / ABS_Y values still reported
```

Interpretation: v3 restores at least D-pad Up, Down, and one horizontal direction at the Linux input layer while preserving the v2 left-stick fix.

Focused D-pad Left capture:

```bash
timeout 7 evtest /dev/input/event17
```

Observed result:

```text
No input events captured.
```

Interpretation: if D-pad Left was pressed during that focused capture, then D-pad Left is still not being reported and needs a raw-packet check. If no D-pad Left press happened during the capture window, the result is inconclusive for Left only.

### D-pad Left raw USB verification

I verified that D-pad Left was pressed during the focused `evtest` capture.

Commands used:

```bash
sudo bash -lc "timeout 8 cat /sys/kernel/debug/usb/usbmon/1u" \
  | awk '/C Ii:1:063:1/ { payload=$0; sub(/^.* = /, "", payload); count[payload]++ } END { for (p in count) print count[p], p }' \
  | sort -nr | head -20
```

Observed result while D-pad Left was pressed:

```text
7865 00140000 00000000 00000000 00000000 00000000
```

Observed result while D-pad Left was held continuously in a repeat capture:

```text
7673 00140000 00000000 00000000 00000000 00000000
```

Interpretation: the raw USB packet stayed neutral while physical D-pad Left was pressed/held. That means the current driver never receives a D-pad Left signal to map. At this point, D-pad Left is likely a physical contact/button issue or a controller-firmware issue in this mode, not a Wine or Linux event-mapping issue. By contrast, v3 already verified that D-pad Up, Down, and Right can reach Linux as `ABS_HAT0Y`/`ABS_HAT0X`.

### Patch v3 initramfs and Limine refresh

Command used:

```bash
sudo mkinitcpio -P
```

Observed result:

```text
Initcpio image generation successful for linux-cachyos-lts (6.18.28-1-cachyos-lts)
Initcpio image generation successful for linux-cachyos (7.0.5-2-cachyos)
Updated: /boot/limine.conf
```

Interpretation: boot artifacts were refreshed after patch v3 was built, installed, and loaded.

In-game verification note: because `xpad` was reloaded after Max Payne 3 was already running, Max Payne 3 should be fully restarted before testing D-pad Up/painkillers in-game.

### Pre-restart game process check

Command used:

```bash
ps -ef | rg -i 'max|payne|lutris|wine|wineserver|steam'
modinfo -F srcversion xpad
ls -la /dev/input/by-id /dev/input/event17 /dev/input/js0
```

Observed result:

```text
MaxPayne3.exe process was still the instance launched at 01:31
v3 xpad srcversion: D8FA079063ECC1F81AE5CE9
/dev/input/by-id/usb-ZhiXu_Controller-event-joystick -> ../event17
/dev/input/by-id/usb-ZhiXu_Controller-joystick -> ../js0
```

Interpretation: the running Max Payne 3 process predates the v3 driver reload at 01:51. A valid in-game test requires fully restarting Max Payne 3 so Wine opens the current v3 controller device.

### Final Max Payne 3 in-game verification

I verified that D-pad Up started working in the already-running Max Payne 3
session, without restarting the game.

Interpretation: patch v3 is validated in-game for the original Max Payne 3
painkiller issue. The left-stick fix remains preserved at the Linux input layer,
and D-pad Up now works in Max Payne 3.

## Follow-up: Controller Reappeared in HID/DragonRise Mode

### New symptom

While playing Max Payne 3 later, I observed that the left stick and D-pad
behavior were swapped in-game.

### Runtime state

Commands used:

```bash
ps -ef | rg -i 'max|payne|lutris|wine|wineserver|steam|xalia'
lsusb
ls -la /dev/input/by-id /dev/input/event17 /dev/input/js0
modinfo -F srcversion xpad
lsmod | rg 'xpad|hid|joydev|ff_memless|usbmon'
readlink -f /sys/class/input/event5 /sys/class/input/js0 /sys/class/input/event17
```

Observed result:

```text
MaxPayne3.exe is running under Lutris/GE-Proton.
Bus 001 Device 002: ID 0079:181c DragonRise Inc. Gamepad
/dev/input/by-id/usb-ZhiXu_Gamepad-event-joystick -> ../event5
/dev/input/by-id/usb-ZhiXu_Gamepad-joystick -> ../js0
/dev/input/by-id/usb-ZhiXu_Gamepad-hidraw -> ../../hidraw0
event5/js0 path: .../0003:0079:181C.0001/input/input6
event17 path: ImPS/2 Logitech Wheel Mouse
xpad srcversion on disk: D8FA079063ECC1F81AE5CE9
loaded driver path: usbhid / hid-generic
```

Device identity:

```text
name: ZhiXu Gamepad
bustype: 0003
vendor: 0079
product: 181c
version: 0111
USB manufacturer: ZhiXu
USB product: Gamepad
interface class: 03
interface subclass: 00
interface protocol: 00
```

Interpretation: this is not the same runtime mode as the earlier `045e:028e` Xbox 360 clone mode. The controller is currently in HID/DragonRise mode (`0079:181c`) and is handled by `hid-generic`, not by `xpad`. Therefore the previously successful `xpad` v3 patch is not active for the live device in this state. The apparent inversion is likely caused by this alternate HID mode exposing the physical controls differently.

### HID-mode input capture

Command used:

```bash
timeout 15 evtest /dev/input/event5
```

Observed capabilities in HID mode:

```text
Input device name: "ZhiXu Gamepad"
vendor/product: 0079:181c
ABS_X / ABS_Y:      min 0 max 255
ABS_HAT0X / HAT0Y:  min -1 max 1
driver path:        usbhid / hid-generic
```

Observed result while both the physical D-pad and physical left stick were moved:

```text
ABS_HAT0X / ABS_HAT0Y events were emitted for one physical control.
ABS_X / ABS_Y events were emitted for the other physical control.
```

Max Payne 3 labeled those event streams by behavior: in HID mode the physical
left stick acted as D-pad input, while the physical D-pad acted as movement
input.

Interpretation: the live `0079:181c` HID mode presents the same physical
controller through a different report layout. That explains why the in-game
mapping appeared swapped: the kernel was no longer using the patched `xpad`
path at all.

### Negative test: unbind HID interface only

Commands used:

```bash
sudo modprobe xpad
sudo bash -lc "printf '1-3:1.0' > /sys/bus/usb/drivers/usbhid/unbind"
```

Observed result:

```text
The controller immediately returned as:
Bus 001 Device 006: ID 0079:181c DragonRise Inc. Gamepad
driver: hid-generic
```

Interpretation: simply unbinding the current HID driver is not enough. The controller remained in HID/DragonRise mode and did not switch to the patched Xbox-compatible `045e:028e` mode.

### Successful mode-switch fix

Temporary command used for the running boot:

```bash
sudo bash -lc "printf '057e:2009:ik' > /sys/module/usbcore/parameters/quirks"
```

Observed active parameter:

```text
057e:2009:ik
```

After a physical unplug/replug of the controller, the kernel log showed:

```text
usb 1-3: New USB device found, idVendor=045e, idProduct=028e, bcdDevice= 1.10
usb 1-3: Product: Controller
usb 1-3: Manufacturer: ZhiXu
```

Current sysfs/input state after replug:

```text
/sys/bus/usb/devices/1-3/idVendor=045e
/sys/bus/usb/devices/1-3/idProduct=028e
/sys/bus/usb/devices/1-3/manufacturer=ZhiXu
/sys/bus/usb/devices/1-3/product=Controller
/sys/bus/usb/devices/1-3/1-3:1.0/bInterfaceClass=ff
/sys/bus/usb/drivers/xpad/1-3:1.0 exists
/dev/input/by-id/usb-ZhiXu_Controller-event-joystick -> ../event5
loaded xpad srcversion: D8FA079063ECC1F81AE5CE9
```

Interpretation: the controller returned to the Xbox-compatible mode that the v3
`xpad` patch targets. This is the actual fix for the later swapped-mapping
behavior: keep this multi-mode controller out of `0079:181c` HID mode and in
`045e:028e` `xpad` mode.

### Post-fix event verification

Command used:

```bash
timeout 15 /usr/bin/evtest /dev/input/event5
```

Observed device:

```text
Input device ID: bus 0x3 vendor 0x45e product 0x28e version 0x110
Input device name: "Microsoft X-Box 360 pad"
EV_ABS: ABS_X, ABS_Y, ABS_Z, ABS_RX, ABS_RY, ABS_RZ, ABS_HAT0X, ABS_HAT0Y
EV_FF was not listed
```

Observed movement events:

```text
D-pad Up:     ABS_HAT0Y value -1, then 0
D-pad Down:   ABS_HAT0Y value  1, then 0
D-pad Left:   ABS_HAT0X value -1, then 0
D-pad Right:  ABS_HAT0X value  1, then 0
Left stick:   ABS_X / ABS_Y full-scale values
```

Diagonal note:

```text
The capture showed overlapping ABS_X and ABS_Y non-neutral states, so diagonal movement is possible. The controller still reports digital-style full endpoints (-32767 / 32767), not smooth analog values.
```

Interpretation: the corrected Xbox-mode layout is restored. D-pad input is again D-pad hat input, left-stick input is again left-stick axis input, and force feedback remains suppressed for the clone.

### Persistent boot configuration

Backup created before editing:

```text
/etc/default/limine.before-zhixu-usbcore-quirk-20260515
```

Persistent file changed:

```text
/etc/default/limine
```

New command-line entry:

```text
KERNEL_CMDLINE[default]+="quiet nowatchdog splash rw rootflags=subvol=/@ root=UUID=25f33e16-9183-4121-a5a7-13f2c8805e28 usbcore.quirks=057e:2009:ik"
```

Command used to regenerate boot entries:

```bash
sudo limine-update
```

Observed result:

```text
Limine EFI update completed successfully.
Initramfs rebuilt for linux-cachyos-lts (6.18.28-1-cachyos-lts)
Initramfs rebuilt for linux-cachyos (7.0.5-2-cachyos)
Updated: /boot/limine.conf
```

Verification:

```text
/etc/default/limine contains usbcore.quirks=057e:2009:ik
/boot/limine.conf current linux-cachyos cmdline contains usbcore.quirks=057e:2009:ik
/boot/limine.conf current linux-cachyos-lts cmdline contains usbcore.quirks=057e:2009:ik
/sys/module/usbcore/parameters/quirks currently contains 057e:2009:ik
```

Rollback for the persistent quirk:

```bash
sudo cp -a /etc/default/limine.before-zhixu-usbcore-quirk-20260515 /etc/default/limine
sudo limine-update
```

Alternative rollback if the backup is unavailable: remove `usbcore.quirks=057e:2009:ik` from `/etc/default/limine`, then run `sudo limine-update`.

### Final HID-mode regression in-game verification

After the controller was forced back into `045e:028e` Xbox-compatible mode,
Max Payne 3 was tested again without restarting the game. The in-game mapping
was correct.

Interpretation: the later inverted behavior is fixed in the running game. The
root cause was the controller appearing as `0079:181c` HID/DragonRise mode,
bypassing the patched `xpad` driver. The effective fix is the persistent
`usbcore.quirks=057e:2009:ik` kernel parameter plus the existing v3 `xpad`
patch, so the controller enumerates as `045e:028e` and is handled by the
patched `xpad` path.

## Follow-up: Reboot Still Starts in HID Mode Until Replug

### Symptom after reboot

After rebooting with the controller already connected, Max Payne 3 again showed
the swapped left-stick/D-pad behavior. A physical unplug/replug fixed the game
immediately, without restarting it.

### Boot-state evidence

Commands used:

```bash
sed -n '1p' /proc/cmdline
sed -n '1p' /sys/module/usbcore/parameters/quirks
sudo dmesg -T | rg -i 'usb 1-3|ZhiXu|045e|028e|0079|181c|057e|2009|xpad|hid-generic|usbcore|quirks'
```

Observed result:

```text
/proc/cmdline contained usbcore.quirks=057e:2009:ik
/sys/module/usbcore/parameters/quirks contained 057e:2009:ik

[17:54:39] usb 1-3: New USB device found, idVendor=0079, idProduct=181c
[17:54:39] usb 1-3: Product: Gamepad
[17:54:39] usb 1-3: Manufacturer: ZhiXu
[17:54:39] hid-generic ... [ZhiXu Gamepad]

[17:59:43] usb 1-3: USB disconnect
[17:59:46] usb 1-3: New USB device found, idVendor=045e, idProduct=028e
[17:59:46] usb 1-3: Product: Controller
[17:59:46] usb 1-3: Manufacturer: ZhiXu
[17:59:46] usbcore: registered new interface driver xpad
```

Interpretation: the Limine/kernel-parameter persistence was correct. The
remaining failure is a cold-boot enumeration problem: while already plugged in
at boot, this controller can still present as `0079:181c` HID/DragonRise mode.
Once the system is fully booted and the controller gets a fresh re-enumeration,
it returns as `045e:028e` and binds to the patched `xpad` driver.

### Boot-time guard plan

The durable fix is to automate the safe part of the manual workaround:

```text
if ZhiXu 045e:028e is already present:
    do nothing
if ZhiXu 0079:181c is present:
    de-authorize and re-authorize only that USB device
    wait for it to re-enumerate as 045e:028e
```

This does not alter the `xpad` patch. It only handles the controller's bad
boot-time mode selection.

### Repository additions

Files added:

```text
scripts/zhixu-controller-ensure-xpad-mode.sh
systemd/zhixu-controller-ensure-xpad-mode.service
udev/99-zhixu-controller-xpad-mode.rules
```

The script scans `/sys/bus/usb/devices` for manufacturer `ZhiXu` with
`0079:181c`. If found, it writes `0` then `1` to that device's `authorized`
file and checks whether `045e:028e` appears. It exits without action if the
controller is already in Xbox/xpad mode.

The udev rule triggers the same systemd service whenever a USB device with
manufacturer `ZhiXu` and ID `0079:181c` appears. This covers both cold-boot
enumeration and later plug-in events.

### Local installation

Commands used:

```bash
sudo install -Dm755 scripts/zhixu-controller-ensure-xpad-mode.sh /usr/local/sbin/zhixu-controller-ensure-xpad-mode
sudo install -Dm644 systemd/zhixu-controller-ensure-xpad-mode.service /etc/systemd/system/zhixu-controller-ensure-xpad-mode.service
sudo install -Dm644 udev/99-zhixu-controller-xpad-mode.rules /etc/udev/rules.d/99-zhixu-controller-xpad-mode.rules
sudo systemctl daemon-reload
sudo udevadm control --reload
sudo systemctl enable zhixu-controller-ensure-xpad-mode.service
sudo systemctl start zhixu-controller-ensure-xpad-mode.service
```

Observed result:

```text
Created symlink:
/etc/systemd/system/multi-user.target.wants/zhixu-controller-ensure-xpad-mode.service

zhixu-controller-ensure-xpad-mode.service: status=0/SUCCESS
ZhiXu controller is already in Xbox/xpad mode.
```

The udev rule was installed under:

```text
/etc/udev/rules.d/99-zhixu-controller-xpad-mode.rules
```

Validation:

```text
sh -n scripts/zhixu-controller-ensure-xpad-mode.sh -> no syntax errors
udevadm test /sys/bus/usb/devices/1-3 -> rule file loaded with no invalid-key warnings
```

Current device state after running the service:

```text
/sys/bus/usb/devices/1-3/idVendor=045e
/sys/bus/usb/devices/1-3/idProduct=028e
/sys/bus/usb/devices/1-3/manufacturer=ZhiXu
/sys/bus/usb/devices/1-3/product=Controller
/sys/bus/usb/devices/1-3/1-3:1.0/bInterfaceClass=ff
```

Interpretation: the service is installed, enabled, and safe in the current
good state. The remaining validation is the next cold boot with the controller
already plugged in; the expected behavior is that the service catches
`0079:181c` if it appears and re-authorizes it into `045e:028e`.

Rollback:

```bash
sudo systemctl disable --now zhixu-controller-ensure-xpad-mode.service
sudo rm -f /etc/systemd/system/zhixu-controller-ensure-xpad-mode.service
sudo rm -f /usr/local/sbin/zhixu-controller-ensure-xpad-mode
sudo rm -f /etc/udev/rules.d/99-zhixu-controller-xpad-mode.rules
sudo systemctl daemon-reload
sudo udevadm control --reload
```

## Follow-up: Phantom eFootball Dash Dribble / RT Input

Date: 2026-06-27 Asia/Amman

Observed symptom:

```text
In eFootball, the controlled player showed the dash-dribble indicator and
knocked the ball ahead while only the physical left stick was being used.
```

Interpretation of the game behavior:

```text
eFootball's Basic Controls overlay describes Dash Dribble as LS + RT. The
larger ball touch / ball pushed ahead behavior is consistent with the game
receiving RT while the left stick is held.
```

Linux input capture while only the left stick was moved showed repeated
right-trigger events:

```text
ABS_RZ value 255
ABS_RZ value 0
ABS_RZ value 255
ABS_RZ value 0
```

For the Xbox 360 input mapping, `ABS_RZ` is the right trigger (`RT`).

Raw USB packet capture was then used to verify whether this came from the
controller packet before `xpad` processed it.

Command shape used:

```bash
sudo modprobe usbmon
sudo timeout 10 cat /sys/kernel/debug/usb/usbmon/1u \
  | awk '/C Ii:1:029:/ { payload=$0; sub(/^.* = /, "", payload); count[payload]++ } END { for (p in count) print count[p], p }' \
  | sort -nr | head -30
```

Idle-only raw USB result:

```text
4987 00140000 00000000 00000000 00000000 00000000
4976 00140000 00ff0000 00000000 00000000 00000000
```

Interpretation: with no physical input, the packet byte that stock `xpad`
reports as `ABS_RZ` alternated between `0x00` and `0xff`. This is below Wine,
Proton, and eFootball.

Additional capture while `RT` was reportedly held still showed alternating
packets:

```text
2841 00140000 00ff0000 00000000 00000000 00000000
2800 00140000 00000000 00000000 00000000 00000000
```

Conclusion: for this tested `ZhiXu` clone in `045e:028e` Xbox mode, the byte
that the standard Xbox 360 parser uses for `RT` is not a reliable right-trigger
signal. It creates phantom `RT` input at idle and does not expose a distinct
stable held-RT state in the captures.

An attempted debounce/inversion patch was tested after this, because repeated
RT presses skewed the raw byte toward `0x00`. That preserved an intentional RT
press in one evtest capture:

```text
ABS_RZ value 255
```

However, after physical RT release, raw USB remained constant at the same
signature:

```text
run 00 7652
count 00 7652
```

A follow-up full-packet capture while RT was physically released showed no
alternate byte changing:

```text
11810 0014000000000000000000000000000000000000
```

Interpretation: after an RT press, the tested controller can keep reporting the
same raw packet state while RT is physically released. There is no reliable
press/release distinction in the observed Xbox-mode packet stream for the
driver to map.

Final kernel patch decision:

```text
Preserve all previous ZhiXu-scoped fixes:
- startup sequence for the clone
- left stick from D-pad bits to ABS_X / ABS_Y
- physical D-pad from old analog bytes to ABS_HAT0X / ABS_HAT0Y
- force-feedback and LED suppression

Add one optional ZhiXu-scoped eFootball workaround:
- module parameter: zhixu_suppress_rt
- when enabled, force ABS_RZ / RT to released for this clone only
- leave every other physical button/stick mapping unchanged
```

The parameter defaults to disabled, so a normal module load keeps stock raw
`RT` behavior. The final UX is a small foreground helper binary that enables
`zhixu_suppress_rt` while it runs and restores the previous value when it exits.

Rejected userspace direction:

```text
A uinput proxy can suppress ABS_RZ on a virtual controller, but it must grab
the real event device. In eFootball, this made the already-running game behave
as if the controller was disconnected instead of switching to the new virtual
controller. This is not the recommended workaround for this game.
```

Tradeoff: with `zhixu_suppress_rt=1`, `RT` is intentionally unavailable. This
is preferable to reporting phantom or latched full-press `RT` in eFootball.

### Same-device RT suppression build/run

Commands used:

```bash
sudo ./scripts/apply-to-xpad-dkms-source.sh
sudo dkms build --force xpad/r127.9caad15 -k 7.1.1-2-cachyos
sudo dkms install --force xpad/r127.9caad15 -k 7.1.1-2-cachyos
sudo modprobe -r xpad
sudo modprobe xpad
make
sudo ./bin/zhixu-rt-suppress-run
```

Observed result:

```text
ZhiXu RT suppression enabled. Press Ctrl+C to disable it.
/sys/module/xpad/parameters/zhixu_suppress_rt: Y
Input device name: "Microsoft X-Box 360 pad"
Handlers: event17 js0
```

Idle verification of the real controller:

```text
Input device name: "Microsoft X-Box 360 pad"
ABS_RZ value at start: 0
No ABS_RZ events emitted during idle capture.
```

After `Ctrl+C`, the helper restores the previous parameter value. If the
previous value was `N`, `RT` suppression is disabled again.

The user-facing version of this workflow is documented separately in
`docs/efootball-phantom-rt.md`.
