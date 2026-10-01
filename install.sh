#!/usr/bin/env bash
# fleetmux installer
# - Installs tmux-sessions / dev-launcher into ~/.local/bin (overwrites existing)
# - Creates the `ts` symlink
# - Adds the M-q popup binding to ~/.tmux.conf (managed marker block, safe to re-run)
# - Asks for the display language on first install (stored in ~/.config/fleetmux/config)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
TMUX_CONF="$HOME/.tmux.conf"
CONFIG_DIR="$HOME/.config/fleetmux"
CONFIG_FILE="$CONFIG_DIR/config"
MARK_BEGIN="# >>> fleetmux >>>"
MARK_END="# <<< fleetmux <<<"
OLD_CONFIG_DIR="$HOME/.config/tmux-session-kit"
OLD_MARK_BEGIN="# >>> tmux-session-kit >>>"
OLD_MARK_END="# <<< tmux-session-kit <<<"

# Migrate config from the pre-rename location (one-time)
if [[ -d "$OLD_CONFIG_DIR" && ! -d "$CONFIG_DIR" ]]; then
  mv "$OLD_CONFIG_DIR" "$CONFIG_DIR"
fi

# ── Language selection ──────────────────────────────────────
TSK_LANG=""
# shellcheck source=/dev/null
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

if [[ -z "${TSK_LANG:-}" ]]; then
  if [[ -t 0 ]]; then
    echo "Select language / 언어를 선택하세요:"
    echo "  1) English"
    echo "  2) 한국어"
    read -r -p "> " lang_choice
    case "${lang_choice:-}" in
      2) TSK_LANG="ko" ;;
      *) TSK_LANG="en" ;;
    esac
  else
    # Non-interactive install: fall back to the system locale
    case "${LANG:-}" in
      ko*) TSK_LANG="ko" ;;
      *)   TSK_LANG="en" ;;
    esac
  fi
fi
mkdir -p "$CONFIG_DIR"
printf 'TSK_LANG=%s\n' "$TSK_LANG" >"$CONFIG_FILE"

# ── Localized installer messages ────────────────────────────
if [[ "$TSK_LANG" == "ko" ]]; then
  MSG_MISSING_DEPS="오류: 필수 프로그램이 없습니다"
  MSG_INSTALL_HINT="예) sudo apt install"
  MSG_INSTALLED="✓ 설치됨"
  MSG_TMUX_CONF_UPDATED="✓ tmux.conf 바인딩 갱신됨 (M-q → dev-launcher)"
  MSG_TMUX_RELOADED="✓ 실행 중인 tmux 서버에 설정 반영됨"
  MSG_LANG_SAVED="✓ 언어 설정 저장됨"
  MSG_PATH_WARN="주의: 다음 경로가 PATH에 없습니다. 셸 설정에 추가하세요:"
  MSG_OPTIONAL_DEPS="선택 의존성 (dev-launcher 메뉴에서 사용, 없어도 동작):"
  MSG_NOT_INSTALLED="(미설치)"
  MSG_ASK_INSTALL="지금 설치할까요? (y/N): "
  MSG_INSTALLING="설치 중..."
  MSG_INSTALL_OK="✓ 설치 완료"
  MSG_INSTALL_FAIL="✗ 설치 실패 — 수동으로 설치해 주세요"
  MSG_DONE="완료! 사용법:"
  MSG_USAGE_TS="  ts        — 터미널에서 세션 피커 실행 (tmux 안/밖 모두 동작)"
  MSG_USAGE_ALTQ="  Alt+q     — tmux 안에서 dev-launcher 팝업"
  MSG_CLAUDE_HOOKS_ASK="Claude Code 에이전트 상태 연동을 설정할까요? (~/.claude/settings.json에 hooks 추가) (y/N): "
  MSG_CLAUDE_HOOKS_OK="✓ Claude Code hooks 등록됨 — 에이전트 상태가 ts 대시보드에 표시됩니다"
  MSG_CLAUDE_HOOKS_SKIP="  (건너뜀 — 나중에 ./install.sh 재실행으로 설정 가능)"
  MSG_CLAUDE_HOOKS_FAIL="✗ Claude Code hooks 등록 실패 (python3 필요)"
else
  MSG_MISSING_DEPS="Error: required programs are missing"
  MSG_INSTALL_HINT="e.g. sudo apt install"
  MSG_INSTALLED="✓ Installed"
  MSG_TMUX_CONF_UPDATED="✓ tmux.conf binding updated (M-q → dev-launcher)"
  MSG_TMUX_RELOADED="✓ Config reloaded on the running tmux server"
  MSG_LANG_SAVED="✓ Language preference saved"
  MSG_PATH_WARN="Warning: the following path is not in PATH. Add it to your shell config:"
  MSG_OPTIONAL_DEPS="Optional dependencies (used by dev-launcher menus, not required):"
  MSG_NOT_INSTALLED="(not installed)"
  MSG_ASK_INSTALL="install now? (y/N): "
  MSG_INSTALLING="installing..."
  MSG_INSTALL_OK="✓ installed"
  MSG_INSTALL_FAIL="✗ install failed — please install it manually"
  MSG_DONE="Done! Usage:"
  MSG_USAGE_TS="  ts        — session picker in the terminal (works inside and outside tmux)"
  MSG_USAGE_ALTQ="  Alt+q     — dev-launcher popup inside tmux"
  MSG_CLAUDE_HOOKS_ASK="Set up Claude Code agent-status integration? (adds hooks to ~/.claude/settings.json) (y/N): "
  MSG_CLAUDE_HOOKS_OK="✓ Claude Code hooks registered — agent status will show in the ts dashboard"
  MSG_CLAUDE_HOOKS_SKIP="  (skipped — re-run ./install.sh to set it up later)"
  MSG_CLAUDE_HOOKS_FAIL="✗ Failed to register Claude Code hooks (python3 required)"
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  MSG_INSTALL_HINT="brew install"
fi

echo "$MSG_LANG_SAVED: $TSK_LANG ($CONFIG_FILE)"

# ── Dependency check ────────────────────────────────────────
missing=()
for dep in tmux fzf; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if ((${#missing[@]})); then
  # Homebrew needs no sudo and supports both macOS and Linux.
  if command -v brew >/dev/null 2>&1; then
    echo "$MSG_INSTALLING ${missing[*]} (Homebrew)"
    brew install "${missing[@]}"
  fi
  missing=()
  for dep in tmux fzf; do
    command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
  done
  if ((${#missing[@]})); then
    echo "$MSG_MISSING_DEPS: ${missing[*]}" >&2
    echo "$MSG_INSTALL_HINT ${missing[*]}" >&2
    exit 1
  fi
fi

# ── Install scripts (always overwrite existing files) ───────
mkdir -p "$BIN_DIR"
install -m 755 "$SRC_DIR/bin/tmux-sessions"  "$BIN_DIR/tmux-sessions"
install -m 755 "$SRC_DIR/bin/dev-launcher"   "$BIN_DIR/dev-launcher"
install -m 755 "$SRC_DIR/bin/fleetmux-hook"  "$BIN_DIR/fleetmux-hook"
ln -sf "$BIN_DIR/tmux-sessions" "$BIN_DIR/ts"
echo "$MSG_INSTALLED: $BIN_DIR/tmux-sessions, $BIN_DIR/dev-launcher, $BIN_DIR/fleetmux-hook, $BIN_DIR/ts"

# ── tmux.conf binding (remove old kit block, then append) ───
touch "$TMUX_CONF"
if grep -qF "$MARK_BEGIN" "$TMUX_CONF"; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$TMUX_CONF"
  else
    sed -i "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$TMUX_CONF"
  fi
fi
if grep -qF "$OLD_MARK_BEGIN" "$TMUX_CONF"; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "/^$OLD_MARK_BEGIN\$/,/^$OLD_MARK_END\$/d" "$TMUX_CONF"
  else
    sed -i "/^$OLD_MARK_BEGIN\$/,/^$OLD_MARK_END\$/d" "$TMUX_CONF"
  fi
fi
cat >>"$TMUX_CONF" <<EOF
$MARK_BEGIN
# Alt+q: dev-launcher popup (Sessions/Tree/Git/Docker/Files/...)
bind-key -n M-q display-popup -E -d '#{pane_current_path}' -w 70% -h 60% "$BIN_DIR/dev-launcher"
$MARK_END
EOF
echo "$MSG_TMUX_CONF_UPDATED"

# ── Reload the running tmux server, if any ──────────────────
if tmux info >/dev/null 2>&1; then
  tmux source-file "$TMUX_CONF" 2>/dev/null || true
  echo "$MSG_TMUX_RELOADED"
fi

# ── PATH check ──────────────────────────────────────────────
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo
    echo "$MSG_PATH_WARN"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

# ── Claude Code hooks (agent-status integration) ────────────
setup_claude_hooks() {
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$BIN_DIR" <<'PYEOF'
import json, os, sys

bin_dir = sys.argv[1]
path = os.path.expanduser("~/.claude/settings.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
settings = {}
if os.path.exists(path):
    with open(path) as f:
        settings = json.load(f)

hooks = settings.setdefault("hooks", {})
wanted = {
    "UserPromptSubmit": f"{bin_dir}/fleetmux-hook working || true",
    "Notification":     f"{bin_dir}/fleetmux-hook attention || true",
    "Stop":             f"{bin_dir}/fleetmux-hook waiting || true",
}

for event, command in wanted.items():
    entries = hooks.setdefault(event, [])
    existing = [h.get("command", "") for e in entries for h in e.get("hooks", [])]
    if any("fleetmux-hook" in c for c in existing):
        continue
    entries.append({"hooks": [{"type": "command", "command": command}]})

with open(path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
PYEOF
}

if [[ -t 0 ]]; then
  read -r -p "$MSG_CLAUDE_HOOKS_ASK" hooks_answer
  if [[ "${hooks_answer:-}" =~ ^[Yy]$ ]]; then
    if setup_claude_hooks; then
      echo "$MSG_CLAUDE_HOOKS_OK"
    else
      echo "$MSG_CLAUDE_HOOKS_FAIL"
    fi
  else
    echo "$MSG_CLAUDE_HOOKS_SKIP"
  fi
fi

# ── Optional dependency install helpers ─────────────────────
# All methods avoid sudo: brew if available, otherwise GitHub release
# binaries downloaded into ~/.local/bin.
github_latest_tag() {
  # Resolve the latest release tag of a GitHub repo (e.g. "v0.44.1")
  curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$1/releases/latest" | sed 's|.*/tag/||'
}

detect_arch() {
  case "$(uname -m)" in
    x86_64)          echo "x86_64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *)               return 1 ;;
  esac
}

install_optional() {
  local tool="$1" tmp tag ver arch
  if command -v brew >/dev/null 2>&1 && [[ "$tool" != "claude" ]]; then
    brew install "$tool"
    return
  fi
  # The release fallback below contains Linux binaries only. On macOS,
  # use Homebrew for these tools; Claude's official installer supports both.
  if [[ "$(uname -s)" != "Linux" && "$tool" != "claude" ]]; then
    return 1
  fi
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN
  arch=$(detect_arch) || return 1
  case "$tool" in
    lazygit)
      tag=$(github_latest_tag jesseduffield/lazygit)
      ver="${tag#v}"
      [[ "$arch" == "x86_64" ]] && arch_name="x86_64" || arch_name="arm64"
      curl -fsSL -o "$tmp/lg.tar.gz" \
        "https://github.com/jesseduffield/lazygit/releases/download/${tag}/lazygit_${ver}_Linux_${arch_name}.tar.gz"
      tar -xzf "$tmp/lg.tar.gz" -C "$tmp" lazygit
      install -m 755 "$tmp/lazygit" "$BIN_DIR/lazygit"
      ;;
    lazydocker)
      tag=$(github_latest_tag jesseduffield/lazydocker)
      ver="${tag#v}"
      [[ "$arch" == "x86_64" ]] && arch_name="x86_64" || arch_name="arm64"
      curl -fsSL -o "$tmp/ld.tar.gz" \
        "https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${ver}_Linux_${arch_name}.tar.gz"
      tar -xzf "$tmp/ld.tar.gz" -C "$tmp" lazydocker
      install -m 755 "$tmp/lazydocker" "$BIN_DIR/lazydocker"
      ;;
    yazi)
      [[ "$arch" == "x86_64" ]] && rust_arch="x86_64" || rust_arch="aarch64"
      curl -fsSL -o "$tmp/yazi.zip" \
        "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${rust_arch}-unknown-linux-gnu.zip"
      unzip -q "$tmp/yazi.zip" -d "$tmp"
      install -m 755 "$tmp"/yazi-*/yazi "$BIN_DIR/yazi"
      install -m 755 "$tmp"/yazi-*/ya   "$BIN_DIR/ya"
      ;;
    claude)
      curl -fsSL https://claude.ai/install.sh | bash
      ;;
    *)
      return 1
      ;;
  esac
}

# ── Optional dependency report / interactive install ────────
echo
echo "$MSG_OPTIONAL_DEPS"
for opt in lazygit lazydocker yazi claude; do
  if command -v "$opt" >/dev/null 2>&1; then
    echo "  ✓ $opt"
    continue
  fi
  if [[ -t 0 ]]; then
    read -r -p "  ✗ $opt — $MSG_ASK_INSTALL" answer
    if [[ "${answer:-}" =~ ^[Yy]$ ]]; then
      echo "    $MSG_INSTALLING"
      if install_optional "$opt" >/dev/null 2>&1 && command -v "$opt" >/dev/null 2>&1; then
        echo "    $MSG_INSTALL_OK"
      else
        echo "    $MSG_INSTALL_FAIL"
      fi
    fi
  else
    echo "  ✗ $opt $MSG_NOT_INSTALLED"
  fi
done

echo
echo "$MSG_DONE"
echo "$MSG_USAGE_TS"
echo "$MSG_USAGE_ALTQ"
