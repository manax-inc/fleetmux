#!/usr/bin/env bash
# fleetmux uninstaller
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
TMUX_CONF="$HOME/.tmux.conf"
CONFIG_DIR="$HOME/.config/fleetmux"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/fleetmux"
MARK_BEGIN="# >>> fleetmux >>>"
MARK_END="# <<< fleetmux <<<"

rm -f "$BIN_DIR/tmux-sessions" "$BIN_DIR/dev-launcher" "$BIN_DIR/ts" "$BIN_DIR/fleetmux-hook"
rm -rf "$STATE_DIR"
echo "✓ Removed executables"

if [[ -f "$TMUX_CONF" ]] && grep -qF "$MARK_BEGIN" "$TMUX_CONF"; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$TMUX_CONF"
  else
    sed -i "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$TMUX_CONF"
  fi
  echo "✓ Removed tmux.conf binding"
  if tmux info >/dev/null 2>&1; then
    tmux unbind-key -n M-q 2>/dev/null || true
    echo "✓ Unbound M-q on the running tmux server"
  fi
fi

rm -rf "$CONFIG_DIR"
echo "✓ Removed config directory"

echo "Done."
