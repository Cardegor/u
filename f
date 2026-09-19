#!/usr/bin/env bash
set -Eeuo pipefail

STATE_DIR="$HOME/.local/state/surface-ai-setup"
MARKER="$STATE_DIR/done"
LOG="$STATE_DIR/setup.log"
mkdir -p "$STATE_DIR"
exec > >(tee -a "$LOG") 2>&1

if [[ -f "$MARKER" ]]; then
  exit 0
fi

echo "== Surface AI Workstation: user desktop setup =="

export PATH="$HOME/.local/bin:/usr/local/bin:/snap/bin:$PATH"
CACHE="$HOME/.cache/surface-ai-setup"
rm -rf "$CACHE"
mkdir -p "$CACHE" "$HOME/src" "$HOME/.local/bin"

# WhiteSur GTK / GNOME Shell theme
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$CACHE/WhiteSur-gtk-theme"
(
  cd "$CACHE/WhiteSur-gtk-theme"
  ./install.sh
)

# WhiteSur icons; bold panel icons are recommended for high-DPI displays.
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git "$CACHE/WhiteSur-icon-theme"
(
  cd "$CACHE/WhiteSur-icon-theme"
  ./install.sh -b
)

# WhiteSur cursor
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git "$CACHE/WhiteSur-cursors"
(
  cd "$CACHE/WhiteSur-cursors"
  ./install.sh
)

# Just Perfection for GNOME 50
if git clone --depth=1 https://github.com/jrahmatzadeh/just-perfection.git "$CACHE/just-perfection"; then
  (
    cd "$CACHE/just-perfection"
    ./scripts/build.sh -i
  ) || true
fi

# Blur My Shell supports GNOME 50. Install it, but leave it disabled initially.
if git clone --depth=1 https://github.com/aunetx/blur-my-shell.git "$CACHE/blur-my-shell"; then
  (
    cd "$CACHE/blur-my-shell"
    make install
  ) || true
fi

# Install Hermes Agent per user, but defer provider/auth setup.
if ! command -v hermes >/dev/null 2>&1; then
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup --non-interactive
fi

enable_match() {
  local pattern="$1"
  local uuid
  uuid="$(gnome-extensions list 2>/dev/null | grep -i "$pattern" | head -n1 || true)"
  if [[ -n "$uuid" ]]; then
    gnome-extensions enable "$uuid" || true
  fi
}

enable_match "user-theme"
enable_match "workspace-indicator"
enable_match "system-monitor"
enable_match "just-perfection"
gnome-extensions disable blur-my-shell@aunetx 2>/dev/null || true

# GNOME / macOS-inspired appearance
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' || true
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur' || true
gsettings set org.gnome.desktop.interface cursor-theme 'WhiteSur-cursors' || true
gsettings set org.gnome.desktop.interface font-name 'Inter 11' || true
gsettings set org.gnome.desktop.interface document-font-name 'Inter 11' || true
gsettings set org.gnome.desktop.interface show-battery-percentage true || true
gsettings set org.gnome.desktop.interface enable-hot-corners true || true

gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' || true
gsettings set org.gnome.desktop.wm.preferences num-workspaces 9 || true
gsettings set org.gnome.mutter dynamic-workspaces false || true

gsettings set org.gnome.desktop.interface clock-format '24h' || true
gsettings set org.gnome.desktop.interface clock-show-weekday true || true
gsettings set org.gnome.desktop.interface clock-show-date true || true

gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true || true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true || true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true || true

if gsettings list-schemas | grep -qx 'org.gnome.shell.extensions.dash-to-dock'; then
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM' || true
  gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false || true
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false || true
  gsettings set org.gnome.shell.extensions.dash-to-dock autohide true || true
  gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true || true
  gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48 || true
  gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false || true
  gsettings set org.gnome.shell.extensions.dash-to-dock show-trash true || true
  gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'DYNAMIC' || true
fi

if gsettings list-schemas | grep -qx 'org.gnome.shell.extensions.user-theme'; then
  gsettings set org.gnome.shell.extensions.user-theme name 'WhiteSur-Dark' || true
fi

# Codex IDE extension for VS Code
if command -v code >/dev/null 2>&1; then
  code --install-extension openai.chatgpt --force || true
elif [[ -x /snap/bin/code ]]; then
  /snap/bin/code --install-extension openai.chatgpt --force || true
fi

# Hindsight helper: initialize separately inside each SaaS repository.
cat > "$HOME/.local/bin/hindsight-codex-init" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec npx -y @vectorize-io/hindsight-coding-agents install codex "$@"
EOF
chmod +x "$HOME/.local/bin/hindsight-codex-init"

cat > "$HOME/src/AGENTS.md.template" <<'EOF'
# AGENTS.md

## Project
Describe this SaaS and the main user flows.

## Stack
- TypeScript / Node.js
- Add framework, database, queue and hosting details here.

## Commands
- Install: pnpm install
- Dev: pnpm dev
- Lint: pnpm lint
- Test: pnpm test
- Typecheck: pnpm typecheck

## Engineering rules
- Keep TypeScript strict.
- Do not commit secrets or .env files.
- Add or update tests for changed business logic.
- Run lint, typecheck and tests before finishing.
- Explain new production dependencies before adding them.
- Never modify production data or production infrastructure without explicit approval.
EOF

cat > "$STATE_DIR/NEXT-STEPS.txt" <<'EOF'
Surface AI Workstation is prepared.

Authenticate/configure:
  codex
  gh auth login
  hermes setup

For a SaaS repository:
  cd ~/src/<repo>
  cp ~/src/AGENTS.md.template AGENTS.md
  hindsight-codex-init

Installed creative tooling:
  Blender (stable classic snap)
  FFmpeg
  ImageMagick

Notes:
- VS Code is installed with the OpenAI Codex extension.
- Blur My Shell is installed but intentionally disabled by default.
- Hindsight is initialized per repository, not globally.
- Higgsfield is a web/service integration; no local desktop package is required.
EOF

touch "$MARKER"
notify-send "Surface AI Workstation" "Desktop-Setup abgeschlossen. Bitte einmal ab- und wieder anmelden." 2>/dev/null || true
echo "== User desktop setup complete =="
