#!/usr/bin/env bash
set -Eeuo pipefail

LOG=/var/log/surface-ai-bootstrap.log
MARKER=/var/lib/surface-ai-bootstrap.done
exec > >(tee -a "$LOG") 2>&1

[[ -f "$MARKER" ]] && exit 0

echo "== Surface AI Workstation: root bootstrap =="
export DEBIAN_FRONTEND=noninteractive

apt-get update

# Development, media and GNOME tooling. Installing this after the first boot
# avoids making the Ubuntu installer sit at "Copying files" for a long time.
apt-get install -y   ca-certificates curl wget git gh build-essential xz-utils jq unzip zip rsync ripgrep   nodejs npm docker.io docker-compose-v2   python3 python3-venv python3-pip python3-dev pipx   sqlite3 postgresql-client ffmpeg imagemagick   gnome-tweaks gnome-shell-extension-manager   gnome-shell-extension-user-theme   gnome-shell-extension-workspace-indicator   gnome-shell-extension-system-monitor   sassc libglib2.0-dev libglib2.0-dev-bin libxml2-utils gettext libnotify-bin fonts-inter

systemctl enable --now docker

if ! command -v pnpm >/dev/null 2>&1; then
  npm install -g pnpm
fi

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh
fi

# Large GUI snaps are deliberately installed here, after Ubuntu itself boots.
snap wait system seed.loaded || true
if ! snap list code >/dev/null 2>&1; then
  snap install code --classic
fi
if ! snap list blender >/dev/null 2>&1; then
  snap install blender --classic
fi

REGULAR_USER="$(awk -F: '$3 >= 1000 && $3 < 60000 && $6 ~ /^\/home\// {print $1; exit}' /etc/passwd || true)"
if [[ -n "$REGULAR_USER" ]]; then
  usermod -aG docker "$REGULAR_USER" || true
  HOME_DIR="$(getent passwd "$REGULAR_USER" | cut -d: -f6)"
  install -d -o "$REGULAR_USER" -g "$REGULAR_USER" "$HOME_DIR/src" "$HOME_DIR/.local/bin"
fi

touch "$MARKER"
echo "== Root bootstrap complete =="
