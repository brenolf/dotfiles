# install/

Machine-aware setup scripts for these dotfiles.

## Usage

```bash
./install/install.sh           # detect this machine and install
./install/install.sh --check   # just print which machine was detected
```

## How it decides what to do

Detection is by **machine identity**, not OS:

| Machine        | Detected by                       | Packages                                   | Config                              |
|----------------|-----------------------------------|--------------------------------------------|-------------------------------------|
| Work (Shopify) | `~/.local/state/tec` exists (TEC) | Homebrew (`Brewfile`)                      | **symlinks** created (no chezmoi)   |
| Personal       | hostname `obelisk` (Nobara/Fedora)| `dnf` (`fedora-packages.txt`) + scripts    | **chezmoi** installed if missing, then `chezmoi init --apply` (no symlinks)|
| Anything else  | —                                 | nothing                                    | nothing — just an alert             |

## Notes

- This folder is excluded from chezmoi via the repo-root `.chezmoiignore`, so it
  is never deployed into `$HOME`.
- The work path also clears the macOS quarantine flag on `Alacritty.app`.
- Symlinks created on the **work** machine:
  - `~/.zshrc`
  - `~/.tmux.conf`
  - `~/.config/starship.toml`
  - `~/.config/alacritty`
  - `~/.config/btop`
  - `~/.config/agent-instructions`
  - `~/.claude/CLAUDE.md`
  - `~/.pi/agent/AGENTS.md`
- Existing real files at those paths are moved to `~/.dotfiles-backup-<timestamp>/`
  before linking (the script is idempotent — re-running skips already-correct links).
