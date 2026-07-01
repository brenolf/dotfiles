#!/usr/bin/env bash
#
# Dotfiles installer.
#
# Decides what to do based on WHICH MACHINE this is (not the OS):
#
#   - Work machine     -> detected by TEC (Shopify dev tooling). Installs packages
#                         via Homebrew AND creates config symlinks (no chezmoi at work).
#   - Personal machine -> detected by hostname "obelisk" (Nobara/Fedora). Installs
#                         packages via dnf. Config is managed by chezmoi, so NO symlinks.
#   - Anything else    -> does nothing except print an alert.
#
# Usage:
#   ./install/install.sh           # detect machine and install
#   ./install/install.sh --check   # just print which machine was detected
#
set -euo pipefail

# Resolve the repo root from this script's location, so it works no matter
# where the repo is cloned.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- output helpers --------------------------------------------------------
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }

# --- machine detection -----------------------------------------------------
is_work() { [[ -d "$HOME/.local/state/tec" ]]; }   # Shopify TEC tooling

is_personal() {
    local h
    h="$(hostname 2>/dev/null)"; h="${h%%.*}"        # strip any domain suffix
    [[ "$h" == "obelisk" ]]
}

machine_kind() {
    if is_work; then echo work
    elif is_personal; then echo personal
    else echo unknown
    fi
}

# --- symlinks (work machine only) ------------------------------------------
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

link() {
    local src="$1" dst="$2"
    if [[ ! -e "$src" && ! -L "$src" ]]; then
        warn "source missing, skipping: $src"; return
    fi
    if [[ -L "$dst" ]]; then
        if [[ "$(readlink "$dst")" == "$src" ]]; then ok "already linked: $dst"; return; fi
        rm -f "$dst"
    elif [[ -e "$dst" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$dst" "$BACKUP_DIR/"
        warn "backed up existing $dst -> $BACKUP_DIR/"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "linked $dst -> $src"
}

create_symlinks() {
    log "Creating config symlinks -> $REPO_DIR"
    link "$REPO_DIR/dot_zshrc"                "$HOME/.zshrc"
    link "$REPO_DIR/dot_tmux.conf"            "$HOME/.tmux.conf"
    link "$REPO_DIR/dot_config/starship.toml" "$HOME/.config/starship.toml"
    link "$REPO_DIR/dot_config/alacritty"     "$HOME/.config/alacritty"
    link "$REPO_DIR/dot_config/btop"          "$HOME/.config/btop"
    link "$REPO_DIR/dot_pi/agent/AGENTS.md"   "$HOME/.pi/agent/AGENTS.md"
    link "$REPO_DIR/dot_pi/agent/AGENTS.md"   "$HOME/.claude/CLAUDE.md"
}

# --- work (macOS / Homebrew) -----------------------------------------------
install_work() {
    log "Work machine detected (TEC present)."

    if ! command -v brew >/dev/null 2>&1; then
        warn "Homebrew not found. Install it from https://brew.sh then re-run."
        exit 1
    fi

    log "Installing packages from Brewfile..."
    brew bundle --file="$SCRIPT_DIR/Brewfile"

    # Alacritty is quarantined when installed via cask; clear it so it opens.
    if [[ -d /Applications/Alacritty.app ]]; then
        log "Removing quarantine attribute from Alacritty.app"
        xattr -rd com.apple.quarantine /Applications/Alacritty.app 2>/dev/null || true
    fi

    create_symlinks
    ok "Work setup complete."
}

# --- personal (Fedora / dnf) -----------------------------------------------
ensure_chezmoi() {
    if command -v chezmoi >/dev/null 2>&1; then return; fi
    log "chezmoi not found — installing to ~/.local/bin"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
}

install_personal() {
    log "Personal machine detected (obelisk)."

    if ! command -v dnf >/dev/null 2>&1; then
        warn "dnf not found — expected Fedora/Nobara. Aborting."
        exit 1
    fi

    log "Installing packages from fedora-packages.txt..."
    # shellcheck disable=SC2046
    sudo dnf install -y $(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$SCRIPT_DIR/fedora-packages.txt")

    # starship isn't reliably in Fedora repos -> official installer.
    if ! command -v starship >/dev/null 2>&1; then
        log "Installing starship via official script"
        curl -sS https://starship.rs/install/install.sh | sh -s -- --yes
    fi

    # MesloLGS Nerd Font (no Fedora package) -> download from nerd-fonts release.
    local font_dir="$HOME/.local/share/fonts/Meslo"
    if [[ ! -d "$font_dir" ]]; then
        log "Installing MesloLGS Nerd Font"
        mkdir -p "$font_dir"
        curl -fsSL -o /tmp/Meslo.zip \
            https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip
        unzip -oq /tmp/Meslo.zip -d "$font_dir"
        rm -f /tmp/Meslo.zip
        fc-cache -f "$font_dir" >/dev/null 2>&1 || true
    fi

    # Config is managed by chezmoi on personal machines (no symlinks).
    ensure_chezmoi
    log "Applying dotfiles with chezmoi (source: $REPO_DIR)"
    chezmoi init --apply --source="$REPO_DIR"

    warn "Open tmux and press 'prefix + I' (Ctrl-Space, Shift-i) to install tmux plugins."
    ok "Personal setup complete."
}

# --- main ------------------------------------------------------------------
kind="$(machine_kind)"

if [[ "${1:-}" == "--check" || "${1:-}" == "-n" ]]; then
    log "Detected machine: $kind"
    exit 0
fi

case "$kind" in
    work)     install_work ;;
    personal) install_personal ;;
    unknown)
        warn "This is neither Breno's work nor personal machine."
        warn "Nothing will be installed — these dotfiles are personal."
        warn "If this *is* yours, add detection to install/install.sh."
        exit 0
        ;;
esac
