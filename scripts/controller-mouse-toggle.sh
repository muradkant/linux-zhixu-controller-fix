#!/usr/bin/env bash

set -u

unit=controller-mouse.service

if systemctl --user is-active --quiet "$unit"; then
    systemctl --user stop "$unit"
    notify-send 'Controller mouse disabled'
else
    systemctl --user start "$unit"
    notify-send 'Controller mouse enabled'
fi
