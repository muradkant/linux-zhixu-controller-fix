# Phantom right-trigger suppression

The tested ZhiXu `045e:028e` clone reports unreliable right-trigger input in
Xbox mode. eFootball rendered it as unsolicited dash dribble while only the
left stick moved.

Linux exposes Xbox 360 `RT` as `ABS_RZ`. Raw USB capture proved the fault below
Wine and the game: its source byte alternated between `0x00` and `0xff` at idle,
showed no stable held state, and could remain latched after release. No other
packet byte tracked the physical trigger reliably.

The patch therefore adds a device-scoped module parameter:

```text
/sys/module/xpad/parameters/zhixu_suppress_rt
```

It defaults to `N`. When `Y`, only this clone's `ABS_RZ` is forced to released;
the real controller remains on its original event and joystick nodes, with no
grab or virtual proxy. The unavoidable tradeoff is that physical `RT` is also
unavailable.

After installing and loading the patched driver, build and run the scoped
helper:

```sh
make
sudo ./bin/zhixu-rt-suppress-run
```

It remembers the current parameter, writes `Y`, waits in the foreground, and
restores the remembered value on `Ctrl+C`, `SIGTERM`, or `SIGHUP`. `SIGKILL`
cannot be handled; restore manually after one:

```sh
echo N | sudo tee /sys/module/xpad/parameters/zhixu_suppress_rt
```

Manual enable and disable affect the current module load only:

```sh
echo Y | sudo tee /sys/module/xpad/parameters/zhixu_suppress_rt
echo N | sudo tee /sys/module/xpad/parameters/zhixu_suppress_rt
```

To state the disabled boot default explicitly:

```sh
echo 'options xpad zhixu_suppress_rt=0' | \
  sudo tee /etc/modprobe.d/zhixu-xpad.conf
```

Verify idle suppression with `evtest`: `ABS_RZ` should begin at `0` and emit no
events while untouched. All other mappings remain governed by the main ZhiXu
patch.
