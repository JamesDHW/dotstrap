export PATH="/opt/homebrew/bin:$PATH"

export HOMEBREW_BREWFILE="$HOME/.config/Brewfile"

[ -f "$(brew --prefix)/etc/brew-wrap" ] && source "$(brew --prefix)/etc/brew-wrap"
