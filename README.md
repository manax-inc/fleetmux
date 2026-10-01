# fleetmux

**A tmux-native dashboard for your fleet of AI coding agents.**

Run multiple AI agents (Claude Code, or anything that can call a shell command)
across tmux sessions, and see at a glance which one needs your input — all in
plain bash + tmux + fzf. No Electron, no daemon, no wrapper around your agent.

![ts session picker](docs/ts-picker.png)

## What you get

- **`ts` (tmux-sessions)** — fzf session picker & agent dashboard.
  Outside tmux it attaches; inside tmux it uses `switch-client`, so there are
  no nested-session problems. Sessions where an agent needs attention sort to
  the top with live status badges:

  ```
  ● api-server*   3w  claude: needs attention   permission request
  ● factory       1w  claude: working           editing files
    frontend      2w  -                         15m
  ```

- **`fleetmux-hook`** — one tiny command that any agent can call to report its
  status (`working` / `waiting` / `attention` / `done`). Claude Code is wired
  up automatically via its hooks system if you opt in during install.
- **`dev-launcher`** — tmux popup launcher (`Alt+q`) with Sessions / Tree /
  Git (lazygit) / Docker (lazydocker) / Files (yazi) / Claude, plus your own
  custom entries.

![dev-launcher popup](docs/dev-launcher.png)

## Install

```bash
git clone https://github.com/manax-inc/fleetmux.git
cd fleetmux
./install.sh
```

The installer asks for your display language (English / 한국어) on first run,
then (safe to re-run):

- Installs `tmux-sessions`, `dev-launcher`, `fleetmux-hook`, and the `ts`
  symlink into `~/.local/bin/` — **overwriting existing files**
- Adds the `M-q` popup binding to `~/.tmux.conf` (managed marker block)
- Optionally registers Claude Code hooks for agent-status reporting (asks y/N)
- Offers to install missing optional tools (asks per tool, sudo-free)
- Automatically installs missing required tools (`tmux`, `fzf`) with Homebrew
  when available; otherwise prints the manual installation command
- Reloads the config on a running tmux server, if any

## Picker keys

| Key | Action |
|---|---|
| `Enter` | attach selected session (typing an unmatched name creates a new session) |
| `Ctrl-N` | force-create a session with the typed name |
| `Ctrl-R` | rename the selected session — in place, list refreshes instantly |
| `Ctrl-X` | kill the selected session (`1` = yes / `2` = no) — in place |
| `Ctrl-F` | directory sessionizer: pick a project dir (zoxide if installed), get a session there |
| `Ctrl-P` | create a session from a preset |
| `Esc` | quit |

Also: `ts -` toggles to the previously used session, `ts --version`, `ts --help`.

## Agent status integration

### Claude Code (automatic)

Say `y` at the installer prompt. It adds three hooks to
`~/.claude/settings.json` (idempotent, keeps your existing hooks):

| Claude Code event | Dashboard status |
|---|---|
| `UserPromptSubmit` | 🟢 working |
| `Notification` (permission requests etc.) | 🟡 needs attention |
| `Stop` (turn finished) | 🔵 waiting for input |

### Any other agent (manual)

Have it run `fleetmux-hook <status> [detail]` inside the tmux session:

```bash
FLEETMUX_AGENT=codex fleetmux-hook working "running tests"
fleetmux-hook attention "needs code review"
```

State lives in `~/.local/state/fleetmux/agents/<session>.state` — one JSON
line per session. Hooks never fail and never block the agent.

## Session presets

`~/.config/fleetmux/presets/api.conf`:

```ini
root=~/projects/api
window=editor:vim
window=server:npm run dev
window=logs:
```

`Ctrl-P` in the picker lists presets; picking one creates the session with
those windows and commands, rooted at `root`.

## Custom launcher entries

`~/.config/fleetmux/launcher.conf` — one `icon|label|command` per line:

```
|htop|htop
󰖟|Serve|python3 -m http.server
```

Entries appear in the `Alt+q` menu between the built-ins and Exit.

## Dependencies

| Kind | Package | Used for | When missing |
|---|---|---|---|
| **Required** | `tmux` | everything | installed with Homebrew, otherwise installer aborts |
| **Required** | `fzf` | picker UI | installed with Homebrew, otherwise installer aborts |
| Optional | `lazygit` | dev-launcher → Git | menu shows a notice |
| Optional | `lazydocker` | dev-launcher → Docker | menu shows a notice |
| Optional | `yazi` | dev-launcher → Files | menu shows a notice |
| Optional | `claude` | dev-launcher → Claude | menu shows a notice |
| Optional | `zoxide` | Ctrl-F sessionizer | falls back to `SESSIONIZER_PATHS` |
| Optional | `python3` | Claude hooks setup | hook setup skipped |

```bash
# Ubuntu/Debian
sudo apt install tmux fzf

# macOS
brew install tmux fzf
```

Linux and macOS are supported, including the Bash 3.2 shipped with macOS.
On macOS, install optional launcher tools with Homebrew; the automatic
release-binary fallback is Linux-only. Add `~/.local/bin` to your shell's
PATH as prompted by the installer. In iTerm2, set Option to Esc+ if you
want to use the `Alt+q` launcher binding.

## Configuration

`~/.config/fleetmux/config`:

```bash
TSK_LANG=en                              # or ko
SESSIONIZER_PATHS=~/projects:~/work      # Ctrl-F search roots (when no zoxide)
```

## Uninstall

```bash
./uninstall.sh
```

Removes the executables, the tmux.conf block, agent state, and the config
directory. Claude Code hooks in `~/.claude/settings.json` are left in place
(they fail silently once `fleetmux-hook` is gone); remove them manually if
you want them gone.

## License

MIT
