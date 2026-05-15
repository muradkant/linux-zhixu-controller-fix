#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-/usr/src/xpad-r127.9caad15/xpad.c}"
backup="${target}.before-linux-zhixu-controller-fix"

if [[ ! -f "$repo_root/src/xpad.c" ]]; then
  echo "Missing patched source: $repo_root/src/xpad.c" >&2
  exit 1
fi

if [[ ! -f "$target" ]]; then
  echo "Target xpad.c not found: $target" >&2
  echo "Pass the target path explicitly if your DKMS source tree differs." >&2
  exit 1
fi

sudo cp -a "$target" "$backup"
sudo cp -a "$repo_root/src/xpad.c" "$target"

echo "Installed patched xpad.c to $target"
echo "Backup written to $backup"
echo "Rebuild DKMS and reload xpad for the change to take effect."
