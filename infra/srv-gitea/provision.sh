#!/usr/bin/env bash
# Provision the development-tier Gitea on srv: one LXD container, the Gitea binary under systemd,
# PostgreSQL on an existing server, HTTP on the LAN. Run ON srv as a user in the lxd group.
#
#   DB_HOST=pg.example DB_PASS=... DOMAIN=forge.example.com ./provision.sh
#
# Idempotent where it matters: re-running updates the binary and app.ini but keeps data.
# Everything the author decides is an environment variable with a default below.
# Secrets never reach stdout: generated keys stay in app.ini (root:git 640) and initial passwords
# in /root/gitea-initial-passwords.txt inside the container; pass DB_PASS via the environment or
# a file, not on a command line that lands in shell history or an agent transcript.
set -euo pipefail

CONTAINER="${CONTAINER:-gitea}"
IMAGE="${IMAGE:-ubuntu:26.04}"                 # current Ubuntu LTS from the ubuntu: remote (author: use the LTS)
GITEA_VERSION="${GITEA_VERSION:-1.24.5}"      # matches the NAS instance today
DOMAIN="${DOMAIN:-forge.gnomatix.com}"        # the LAN DNS name the author adds for this tier
HTTP_PORT="${HTTP_PORT:-3000}"
SSH_PORT="${SSH_PORT:-2222}"                  # Gitea's built-in SSH server (remotes stay HTTPS by rule)
ROOT_URL="${ROOT_URL:-https://$DOMAIN/}"       # what browsers see: HTTPS terminated by the NAS nginx, plain HTTP on the LAN
PROXY_IP="${PROXY_IP:-192.168.1.83}"          # the reverse proxy (NAS), trusted for X-Forwarded-For
LAN_SSH_HOST="${LAN_SSH_HOST:-srv.gnomatix.com}" # built-in SSH is LAN-only (remotes are HTTPS by rule)
DB_TYPE="${DB_TYPE:-postgres}"
DB_HOST="${DB_HOST:?set DB_HOST to the PostgreSQL host[:port] (the Atlassian tools server)}"
DB_NAME="${DB_NAME:-gitea}"
DB_USER="${DB_USER:-gitea}"
DB_PASS="${DB_PASS:?set DB_PASS for the $DB_USER role}"
DB_SSL="${DB_SSL:-disable}"                   # prefer 'require' when the server has a certificate
ADMIN_USER="${ADMIN_USER:-brett}"
ADMIN_EMAIL="${ADMIN_EMAIL:-brett@gnomatix.com}"
SERVICE_USER="${SERVICE_USER:-claude-cli}"    # the agents' account, same name as on the NAS
SERVICE_EMAIL="${SERVICE_EMAIL:-claude-cli@noreply.gnomatix.com}"

log() { printf '\n== %s\n' "$*"; }
in_c() { lxc exec "$CONTAINER" -- bash -euo pipefail -c "$*"; }

log "container $CONTAINER ($IMAGE)"
if ! lxc info "$CONTAINER" >/dev/null 2>&1; then
  lxc launch "$IMAGE" "$CONTAINER"
  sleep 8
fi
lxc start "$CONTAINER" 2>/dev/null || true
until in_c 'systemctl is-system-running --wait >/dev/null 2>&1 || true; test -e /run/systemd/resolve/resolv.conf -o -e /etc/resolv.conf'; do sleep 2; done

log "packages"
in_c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -q && apt-get install -yq git git-lfs curl ca-certificates openssh-client >/dev/null'

log "git user and directories"
in_c 'id git >/dev/null 2>&1 || adduser --system --shell /bin/bash --gecos "Git Version Control" --group --disabled-password --home /home/git git
      mkdir -p /var/lib/gitea/{custom,data,log} /etc/gitea
      chown -R git:git /var/lib/gitea && chmod -R 750 /var/lib/gitea
      chown root:git /etc/gitea && chmod 770 /etc/gitea'

log "gitea $GITEA_VERSION binary (sha256 verified)"
in_c "cd /tmp && curl -fsSLO https://dl.gitea.com/gitea/$GITEA_VERSION/gitea-$GITEA_VERSION-linux-amd64 \
      && curl -fsSLO https://dl.gitea.com/gitea/$GITEA_VERSION/gitea-$GITEA_VERSION-linux-amd64.sha256 \
      && sha256sum -c gitea-$GITEA_VERSION-linux-amd64.sha256 \
      && install -m 0755 gitea-$GITEA_VERSION-linux-amd64 /usr/local/bin/gitea && rm -f gitea-$GITEA_VERSION-linux-amd64*"

log "app.ini"
SECRET_KEY="$(in_c 'gitea generate secret SECRET_KEY' | tr -d '\r\n')"
INTERNAL_TOKEN="$(in_c 'gitea generate secret INTERNAL_TOKEN' | tr -d '\r\n')"
JWT_SECRET="$(in_c 'gitea generate secret JWT_SECRET' | tr -d '\r\n')"
if in_c 'test -s /etc/gitea/app.ini'; then
  # keep the secrets of an existing install
  SECRET_KEY="$(in_c "awk -F' = ' '/^SECRET_KEY/{print \$2}' /etc/gitea/app.ini" | tr -d '\r\n')"
  INTERNAL_TOKEN="$(in_c "awk -F' = ' '/^INTERNAL_TOKEN/{print \$2}' /etc/gitea/app.ini" | tr -d '\r\n')"
  JWT_SECRET="$(in_c "awk -F' = ' '/^JWT_SECRET/{print \$2}' /etc/gitea/app.ini" | tr -d '\r\n')"
fi
lxc exec "$CONTAINER" -- bash -c 'cat > /etc/gitea/app.ini' <<INI
APP_NAME = gnomatix forge
RUN_USER = git
RUN_MODE = prod
WORK_PATH = /var/lib/gitea

[server]
PROTOCOL = http
DOMAIN = $DOMAIN
ROOT_URL = $ROOT_URL
HTTP_ADDR = 0.0.0.0
HTTP_PORT = $HTTP_PORT
START_SSH_SERVER = true
SSH_DOMAIN = $LAN_SSH_HOST
SSH_PORT = $SSH_PORT
SSH_LISTEN_PORT = $SSH_PORT
LFS_START_SERVER = true
LFS_JWT_SECRET = $JWT_SECRET
OFFLINE_MODE = true

[database]
DB_TYPE = $DB_TYPE
HOST = $DB_HOST
NAME = $DB_NAME
USER = $DB_USER
PASSWD = $DB_PASS
SSL_MODE = $DB_SSL
LOG_SQL = false

[repository]
ROOT = /var/lib/gitea/data/gitea-repositories
DEFAULT_PRIVATE = private
ENABLE_PUSH_CREATE_USER = true
ENABLE_PUSH_CREATE_ORG = true

[mirror]
ENABLED = true
DEFAULT_INTERVAL = 2h
MIN_INTERVAL = 10m

[git]
LARGE_OBJECT_THRESHOLD = 1048576

[git.timeout]
DEFAULT = 360
MIGRATE = 1200
MIRROR = 600
CLONE = 600
PULL = 600
GC = 120

[service]
DISABLE_REGISTRATION = true
REQUIRE_SIGNIN_VIEW = false
DEFAULT_KEEP_EMAIL_PRIVATE = true
ENABLE_NOTIFY_MAIL = false

[security]
INSTALL_LOCK = true
SECRET_KEY = $SECRET_KEY
INTERNAL_TOKEN = $INTERNAL_TOKEN
PASSWORD_HASH_ALGO = pbkdf2
; the NAS nginx terminates TLS; trust its forwarded headers so logs and rate limits see real clients
REVERSE_PROXY_TRUSTED_PROXIES = 127.0.0.1,::1,$PROXY_IP
REVERSE_PROXY_LIMIT = 1

[migrations]
; LAN topology: the archive-tier Gitea, the GitHub mirror and future LAN services are legitimate
; migration sources and mirror targets; Gitea blocks private addresses unless told otherwise
ALLOW_LOCALNETWORKS = true

[webhook]
ALLOWED_HOST_LIST = private,loopback,external
DELIVER_TIMEOUT = 30

[session]
PROVIDER = file

[log]
MODE = file
LEVEL = Info
ROOT_PATH = /var/lib/gitea/log

[lfs]
PATH = /var/lib/gitea/data/lfs

[cron.update_mirrors]
SCHEDULE = @every 2h

[indexer]
; code search across every repository (built-in Bleve index; switch to meilisearch/elasticsearch if it ever outgrows this)
REPO_INDEXER_ENABLED = true
REPO_INDEXER_TYPE = bleve
REPO_INDEXER_PATH = /var/lib/gitea/data/indexers/repos.bleve
REPO_INDEXER_INCLUDE =
REPO_INDEXER_EXCLUDE = **/*.import,**/*.uid,**/*.png,**/*.jpg,**/*.jpeg,**/*.webp,**/*.gif,**/*.mp3,**/*.wav,**/*.ogg,**/*.mp4,**/*.pck,**/*.wasm,**/node_modules/**
MAX_FILE_SIZE = 1048576
ISSUE_INDEXER_TYPE = bleve
ISSUE_INDEXER_PATH = /var/lib/gitea/data/indexers/issues.bleve
STARTUP_TIMEOUT = 60s

[actions]
; built-in CI; a runner (act_runner) in a second container registers against it later
ENABLED = true
DEFAULT_ACTIONS_URL = github

[packages]
ENABLED = true

[attachment]
ENABLED = true
MAX_SIZE = 64
MAX_FILES = 10

[ui]
DEFAULT_THEME = gitea-auto
INI
in_c 'chown root:git /etc/gitea/app.ini && chmod 640 /etc/gitea/app.ini'

log "systemd unit"
lxc exec "$CONTAINER" -- bash -c 'cat > /etc/systemd/system/gitea.service' <<'UNIT'
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target

[Service]
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT
in_c 'systemctl daemon-reload && systemctl enable --now gitea && sleep 3 && systemctl --no-pager --lines=5 status gitea | head -12'

log "LAN exposure: proxy devices from the host (skip if the container is bridged onto the LAN)"
if ! lxc config device show "$CONTAINER" | grep -q '^http:'; then
  lxc config device add "$CONTAINER" http proxy "listen=tcp:0.0.0.0:$HTTP_PORT" "connect=tcp:127.0.0.1:$HTTP_PORT"
fi
if ! lxc config device show "$CONTAINER" | grep -q '^ssh:'; then
  lxc config device add "$CONTAINER" ssh proxy "listen=tcp:0.0.0.0:$SSH_PORT" "connect=tcp:127.0.0.1:$SSH_PORT"
fi

log "accounts (initial passwords are written to /root/gitea-initial-passwords.txt INSIDE the container, mode 600; never printed)"
mk_user() { # name email admin?
  if in_c "su git -s /bin/bash -c 'gitea admin user list --config /etc/gitea/app.ini' | awk '{print \$2}' | grep -qx '$1'"; then
    echo "user $1 exists"; return
  fi
  in_c "pw=\$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)
        su git -s /bin/bash -c \"gitea admin user create --config /etc/gitea/app.ini --username $1 --email $2 --password \$pw --must-change-password=true $3\" >/dev/null
        umask 077; printf '%s %s\\n' '$1' \"\$pw\" >> /root/gitea-initial-passwords.txt"
  echo "created $1 (must change password at first login; initial password in the container's /root/gitea-initial-passwords.txt)"
}
mk_user "$ADMIN_USER" "$ADMIN_EMAIL" "--admin"
mk_user "$SERVICE_USER" "$SERVICE_EMAIL" "--admin"

log "done: $ROOT_URL (container $CONTAINER on $(hostname)); next: infra/srv-gitea/migrate-repo.sh"
