"""Exercise platform-sensitive paths with isolated config and fake tools."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PlatformTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="fleetmux-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.tools = self.home / "tools"
        self.tools.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), TMUX="",
                        PATH=f"{self.tools}:/usr/bin:/bin", LANG="C",
                        XDG_STATE_HOME=str(self.home / "state"))
        self.tool("tmux", 'exit 1\n')
        self.tool("fzf", 'exit 130\n')

    def tool(self, name, body):
        path = self.tools / name
        path.write_text('#!/bin/bash\n' + body)
        path.chmod(0o755)

    def run_script(self, path, *args):
        return subprocess.run(['/bin/bash', str(ROOT / path), *args],
                              env=self.env, stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, check=True)

    def test_install_reinstall_migrate_uninstall(self):
        conf = self.home / '.tmux.conf'
        conf.write_text('set -g history-limit 12345\n'
                        '# >>> tmux-session-kit >>>\nold binding\n'
                        '# <<< tmux-session-kit <<<\n')
        self.run_script('install.sh')
        first = conf.read_text()
        self.run_script('install.sh')
        self.assertEqual(first, conf.read_text())
        self.assertNotIn('old binding', first)
        self.assertEqual(first.count('# >>> fleetmux >>>'), 1)
        self.assertTrue((self.home / '.local/bin/ts').is_symlink())
        self.run_script('uninstall.sh')
        self.assertEqual(conf.read_text(), 'set -g history-limit 12345\n')
        self.assertFalse((self.home / '.local/bin/ts').exists())

    def test_create_session_without_directory(self):
        self.tool('fzf', "printf 'new-session\\nctrl-n\\n'\n")
        self.tool('tmux', '''case "$1" in
  list-sessions) exit 1 ;;
  new-session) printf '%s\\n' "$@" > "$HOME/tmux-args" ;;
  *) exit 1 ;;
esac
''')
        self.run_script('bin/tmux-sessions')
        self.assertEqual((self.home / 'tmux-args').read_text().splitlines(),
                         ['new-session', '-s', 'new-session'])

    def test_preset_without_root(self):
        presets = self.home / '.config/fleetmux/presets'
        presets.mkdir(parents=True)
        (presets / 'demo.conf').write_text('window=editor:\nwindow=logs:\n')
        self.tool('fzf', '''case "$*" in
  *"preset > "*) printf 'demo\\n' ;;
  *) printf '\\nctrl-p\\n' ;;
esac
''')
        self.tool('tmux', '''case "$1" in
  list-sessions|has-session) exit 1 ;;
  *) printf '%s\\n' "$*" >> "$HOME/tmux-args" ;;
esac
''')
        self.run_script('bin/tmux-sessions')
        self.assertEqual((self.home / 'tmux-args').read_text().splitlines(), [
            'new-session -d -s demo -n editor',
            'new-window -t =demo -n logs',
            'attach-session -t =demo',
        ])


if __name__ == '__main__':
    unittest.main()
