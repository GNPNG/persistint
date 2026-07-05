#!/usr/bin/env bash
# Export the web build and deploy it to gemini-exec-host (192.168.1.241) on srv.
# Served by the persistint-web systemd unit at http://192.168.1.241:8080
set -euo pipefail
cd "$(dirname "$0")/.."
godot --headless --path project --export-release "Web" ../exports/web/index.html
lxc exec srv:gemini-exec-host -- mkdir -p /opt/persistint/web
lxc file push -q -r exports/web srv:gemini-exec-host/opt/persistint/
lxc exec srv:gemini-exec-host -- systemctl restart persistint-web
echo "Deployed: http://192.168.1.241:8080"
