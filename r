#!/usr/bin/env bash
set -Eeuo pipefail

LOG=/var/log/surface-ai-bootstrap.log
MARKER=/var/lib/surface-ai-bootstrap.done
exec > >(tee -a "$LOG") 2>&1

if [[ -f "$MARKER" ]]; then
  exit 0
fi

echo "== Surface AI Workstation: root bootstrap =="
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl git xz-utils build-essential nodejs npm docker.io docker-compose-v2

systemctl enable --now docker

if ! command -v pnpm >/dev/null 2>&1; then
  npm install -g pnpm
fi

if ! command -v codex >/dev/null 2>&1; then
  npm install -g @openai/codex
fi

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh
fi

if ! command -v hermes >/dev/null 2>&1; then
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | env HERMES_HOME=/var/lib/hermes bash -s -- --skip-setup --non-interactive
fi

REGULAR_USER="$(awk -F: '$3 >= 1000 && $3 < 60000 && $6 ~ /^\/home\// {print $1; exit}' /etc/passwd || true)"
if [[ -n "$REGULAR_USER" ]]; then
  usermod -aG docker "$REGULAR_USER" || true
  HOME_DIR="$(getent passwd "$REGULAR_USER" | cut -d: -f6)"
  install -d -o "$REGULAR_USER" -g "$REGULAR_USER" "$HOME_DIR/src" "$HOME_DIR/.local/bin"
fi

touch "$MARKER"
echo "== Root bootstrap complete =="
