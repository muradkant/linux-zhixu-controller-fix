#!/bin/sh
set -eu

bad_vendor="0079"
bad_product="181c"
good_vendor="045e"
good_product="028e"
manufacturer="ZhiXu"
attempts="${ZHIXU_REENUM_ATTEMPTS:-3}"
settle_seconds="${ZHIXU_REENUM_SETTLE_SECONDS:-2}"

read_first_line() {
    sed -n '1p' "$1" 2>/dev/null || true
}

is_device() {
    dev="$1"
    vendor="$2"
    product="$3"

    [ -f "$dev/idVendor" ] || return 1
    [ "$(read_first_line "$dev/idVendor")" = "$vendor" ] || return 1
    [ "$(read_first_line "$dev/idProduct")" = "$product" ] || return 1
    [ "$(read_first_line "$dev/manufacturer")" = "$manufacturer" ] || return 1
}

find_device() {
    vendor="$1"
    product="$2"

    for dev in /sys/bus/usb/devices/*; do
        if is_device "$dev" "$vendor" "$product"; then
            printf '%s\n' "$dev"
            return 0
        fi
    done

    return 1
}

if find_device "$good_vendor" "$good_product" >/dev/null; then
    echo "ZhiXu controller is already in Xbox/xpad mode."
    exit 0
fi

attempt=1
while [ "$attempt" -le "$attempts" ]; do
    bad_dev="$(find_device "$bad_vendor" "$bad_product" || true)"

    if [ -z "$bad_dev" ]; then
        echo "ZhiXu controller is not present in HID/DragonRise mode."
        exit 0
    fi

    if [ ! -w "$bad_dev/authorized" ]; then
        echo "Cannot re-authorize $bad_dev: authorized is not writable." >&2
        exit 1
    fi

    echo "Re-authorizing $bad_dev to leave HID/DragonRise mode (attempt $attempt/$attempts)."
    printf '0\n' > "$bad_dev/authorized"
    sleep 1
    printf '1\n' > "$bad_dev/authorized"
    sleep "$settle_seconds"

    if find_device "$good_vendor" "$good_product" >/dev/null; then
        echo "ZhiXu controller re-enumerated in Xbox/xpad mode."
        exit 0
    fi

    attempt=$((attempt + 1))
done

echo "ZhiXu controller remained in HID/DragonRise mode after $attempts attempts." >&2
exit 1
