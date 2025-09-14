#!/usr/bin/env zsh
set -eu
set -o pipefail

REPO_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) shift; REPO_URL="${1:-}"; shift ;;
    --repo=*) REPO_URL="${1#*=}"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "${REPO_URL:-}" ]] || { echo "Usage: bootstrap.sh --repo <git-url>"; exit 1; }

CONFIG_DIR="${HOME}/.config"

# Centralized cleanup for any temporary directories created during execution
SEED_TMP_DIR=""
TMP_REPO="${TMP_REPO:-}"

cleanup() {
  [[ -n "${SEED_TMP_DIR:-}" && -d "$SEED_TMP_DIR" ]] && rm -rf "$SEED_TMP_DIR"
  [[ -n "${TMP_REPO:-}" && -d "$TMP_REPO" ]] && rm -rf "$TMP_REPO"
}

trap 'cleanup' EXIT

assert_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "Git missing. macOS may prompt to install Command Line Tools."
    xcode-select --install || true
    echo "Re-run after installation completes."
    exit 1
  fi
}

install_brew_if_missing() {
  if command -v brew >/dev/null 2>&1; then return; fi
  echo "Installing Homebrew..."
  
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  local pfx
  [[ "$(uname -m)" == "arm64" ]] && pfx="/opt/homebrew" || pfx="/usr/local"
  echo "eval \"\$(${pfx}/bin/brew shellenv)\"" >> "$HOME/.zprofile"
  eval "$(${pfx}/bin/brew shellenv)"
}

create_config_dir() {
  [[ -d "$CONFIG_DIR" ]] || mkdir -m 700 -p "$CONFIG_DIR"
  git -C "$CONFIG_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || git -C "$CONFIG_DIR" init -q
}

seed_core_modules() {
    local src_root=""

    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        local repo_root
        repo_root="$(git rev-parse --show-toplevel)"
        [[ -d "$repo_root/homebrew" || -d "$repo_root/zsh" ]] && src_root="$repo_root"
    fi

    [[ -n "$src_root" ]] || {
        SEED_TMP_DIR="$(mktemp -d)"
        git clone --depth=1 "https://github.com/JamesDHW/dotstrap.git" "$SEED_TMP_DIR" >/dev/null
        src_root="$SEED_TMP_DIR"
    }

    for mod in homebrew zsh; do
        local dest="$CONFIG_DIR/$mod"
        [[ -e "$dest" ]] && continue
        [[ -d "$src_root/$mod" ]] && ditto "$src_root/$mod" "$dest"
    done

    export HOMEBREW_BREWFILE="$CONFIG_DIR/Brewfile"

    [[ -f "$(brew --prefix)/etc/brew-wrap" ]] && source "$(brew --prefix)/etc/brew-wrap"

    [[ -e "$HOME/.zshenv" ]] || cp "$src_root/template.zshenv" "$HOME/.zshenv"
    [[ -e "$HOME/.zshrc"  ]] || cp "$src_root/template.zshrc"  "$HOME/.zshrc"
}

clone_target_repo() {
  TMP_REPO="$(mktemp -d)"
  git clone --depth=1 "$REPO_URL" "$TMP_REPO" >/dev/null
}

copy_target_repo_modules() {
  local src_cfg="$TMP_REPO"
  [[ -d "$src_cfg" ]] || return 0
  echo "Copying new config modules from target repo..."
  setopt local_options null_glob
  for dir in $src_cfg/*/; do
    local mod; mod="$(basename "$dir")"
    if [[ ! -d "$CONFIG_DIR/$mod" ]]; then
      echo " + $mod"
      rsync -a "$dir" "$CONFIG_DIR/$mod/"
    else
      echo " = $mod (exists, skipping)"
    fi
  done
}

install_target_repo_dependencies() {
  if [[ -f "$TMP_REPO/Brewfile" ]]; then
    if ! command -v brew-file >/dev/null 2>&1; then
        echo "Installing brew-file: required for module management"
        brew install rcmdnk/file/brew-file
    fi

    if grep -q '^appstore ' "$TMP_REPO/Brewfile"; then
        echo "Note: you may need to install mas (brew install mas) and sign into the Mac App Store to install appstore dependencies"
    fi

    echo "Installing brew dependencies from target Brewfile..."
    export HOMEBREW_BREWFILE="$HOME/.config/Brewfile"
    brew file set_repo -r non -y
    brew file install --file="$TMP_REPO/Brewfile" || true
  fi
}

main() {
    assert_git
    install_brew_if_missing
    create_config_dir
    seed_core_modules
    clone_target_repo
    copy_target_repo_modules
    install_target_repo_dependencies
    echo "Done!"
    echo "Don't forget to restart your shell to apply the new config."
    echo "Run 'git remote add origin <your-dotstrap-profile-repo>' to keep your own version of this config and let it evolve over time!"
    echo "Run '/bin/zsh -c \"\$(curl -fsSL https://raw.githubusercontent.com/JamesDHW/dotstrap/main/bootstrap.sh)\" -- --repo <another-dotstrap-profile-repo>' to merge another dotstrap profile into your system!"
}
main
