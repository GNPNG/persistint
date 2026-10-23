#!/usr/bin/env bash
# Export the web build and deploy it to the LXD container that serves it with nginx
# (config: infra/nginx-persistint.conf). Host details come from tools/deploy_web.env
# (not committed; copy tools/deploy_web.env.example).
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=/dev/null
source tools/deploy_web.env
godot --headless --path project --export-release "Web" ../exports/web/index.html
lxc exec "$DEPLOY_LXC" -- mkdir -p /opt/persistint/web
lxc file push -q -r exports/web "$DEPLOY_LXC/opt/persistint/"
lxc exec "$DEPLOY_LXC" -- systemctl reload nginx
echo "Deployed: $DEPLOY_URL"
