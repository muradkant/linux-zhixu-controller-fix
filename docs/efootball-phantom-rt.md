# eFootball Phantom RT Workaround

The tested ZhiXu `045e:028e` Xbox 360 clone can report phantom right-trigger
input in Xbox mode. In eFootball this appears as unintended dash-dribble
behavior while only the left stick is being used.

## Cause

For Xbox 360 controllers, Linux `xpad` exposes the right trigger as
`ABS_RZ`. On the tested controller, the raw USB packet byte that stock `xpad`
uses for `ABS_RZ` alternated between `0x00` and `0xff` while idle. After a
physical `RT` press, the same byte could also remain latched at the raw value
seen while pressed.

Raw USB captures did not show another stable packet byte that tracked the
physical right trigger in Xbox mode. Because of that, this workaround does not
try to recover `RT`; it only disables the unreliable `RT` report while active.

## Runtime Helper

The patched driver adds a module parameter:

```text
/sys/module/xpad/parameters/zhixu_suppress_rt
```

Install and load the patched `xpad` module from the main README first. The
helper expects the parameter above to exist.

Build the helper:

```bash
make
```

Run it while playing:

```bash
sudo ./bin/zhixu-rt-suppress-run
```

While the helper runs, it sets `zhixu_suppress_rt` to `Y`. Stop it with
`Ctrl+C`; it restores the previous parameter value before exiting.
The previous value is not restored if the process is killed with `SIGKILL`.

The controller remains the same real `Microsoft X-Box 360 pad` device. No
virtual controller is created, and the real event device is not grabbed.

## Tradeoff

While the helper is running, `RT` is unavailable. All other controller mappings
remain handled by the core ZhiXu `xpad` patch.

## Manual Control

Enable for the current boot:

```bash
echo Y | sudo tee /sys/module/xpad/parameters/zhixu_suppress_rt
```

Disable for the current boot:

```bash
echo N | sudo tee /sys/module/xpad/parameters/zhixu_suppress_rt
```

Set the boot default to disabled:

```bash
echo 'options xpad zhixu_suppress_rt=0' | sudo tee /etc/modprobe.d/zhixu-xpad.conf
```
