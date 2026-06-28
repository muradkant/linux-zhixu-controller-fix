#!/usr/bin/env bash
set -euo pipefail

duration_idle=${1:-5}
duration_hold=${2:-7}
duration_release=${3:-7}
out_dir=${4:-/tmp}

if [[ $EUID -ne 0 ]]; then
	echo "Run as root: sudo $0 [idle_seconds] [hold_seconds] [release_seconds] [out_dir]" >&2
	exit 2
fi

modprobe usbmon

lsusb_line=$(lsusb -d 045e:028e | head -n 1 || true)
if [[ -z $lsusb_line ]]; then
	echo "No 045e:028e Xbox-mode controller found." >&2
	exit 1
fi

bus=$(awk '{print $2}' <<<"$lsusb_line")
dev=$(awk '{print $4}' <<<"$lsusb_line" | tr -d :)
bus_num=$((10#$bus))
dev_num=$((10#$dev))
monitor="/sys/kernel/debug/usb/usbmon/${bus_num}u"
stamp=$(date +%Y%m%d-%H%M%S)
out_file="${out_dir%/}/zhixu-rt-raw-${stamp}.log"

if [[ ! -r $monitor ]]; then
	echo "Cannot read $monitor" >&2
	exit 1
fi

echo "Capturing bus $bus_num device $dev_num from $monitor"
echo "Output: $out_file"
echo "Plan:"
echo "  ${duration_idle}s: do not touch the controller"
echo "  ${duration_hold}s: hold physical RT only"
echo "  ${duration_release}s: release RT and do not touch the controller"

{
	echo "# $(date --iso-8601=seconds) begin bus=$bus_num dev=$dev_num id=045e:028e"
	echo "# idle ${duration_idle}s"
} >"$out_file"

stdbuf -oL awk -v bus="$bus_num" -v dev="$dev_num" '
	BEGIN {
		pattern = "C Ii:0*" bus ":0*" dev ":"
	}
	$0 ~ pattern {
		payload = $0
		sub(/^.* = /, "", payload)
		print systime(), payload
		fflush()
	}
' "$monitor" >>"$out_file" &
mon_pid=$!

cleanup() {
	kill "$mon_pid" 2>/dev/null || true
	wait "$mon_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep "$duration_idle"
echo "# hold_rt ${duration_hold}s" >>"$out_file"
echo "Now hold physical RT only."
sleep "$duration_hold"
echo "# released ${duration_release}s" >>"$out_file"
echo "Release RT now; do not touch the controller."
sleep "$duration_release"
echo "# end $(date --iso-8601=seconds)" >>"$out_file"

cleanup
trap - EXIT INT TERM

echo
echo "Most common payloads:"
awk '!/^#/ { count[$2]++ } END { for (p in count) print count[p], p }' "$out_file" | sort -nr | head -20
echo
echo "Window summary:"
awk '
	/^# idle/ { window = "idle"; next }
	/^# hold_rt/ { window = "hold_rt"; next }
	/^# released/ { window = "released"; next }
	/^#/ { next }
	window != "" { count[window, $2]++ }
	END {
		for (key in count) {
			split(key, parts, SUBSEP)
			print parts[1], count[key], parts[2]
		}
	}
' "$out_file" | sort -k1,1 -k2,2nr
echo
echo "$out_file"
