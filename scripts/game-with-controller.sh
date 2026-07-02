#!/usr/bin/env bash

set -u

guard="${CONTROLLER_MOUSE_GAME_GUARD:-$HOME/.local/bin/controller-mouse-game-guard}"
token="$$-wrapped-game"

if (( $# == 0 )); then
    printf 'Usage: %s COMMAND [ARG ...]\n' "${0##*/}" >&2
    exit 64
fi

"$guard" --inhibit "$token"

restore_mapper() {
    "$guard" --release "$token"
}
trap restore_mapper EXIT

"$@"
