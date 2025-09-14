# Load per-tool snippets: any ~/.config/*/.zshrc except this one
# Note: snippets are loaded in alphabetical order, configuration in ~/.config/bat/.zshrc will override ~/.config/aws/.zshrc
for f in "$XDG_CONFIG_HOME"/*/.zshrc(N); do
  [[ "$f" == "$ZDOTDIR/.zshrc" ]] && continue
  source "$f"
done

# Load .zshrc in home directory in case there's extra config there
source "$HOME/.zshrc"

alias zshrc="vim ~/.config/zsh/.zshrc"
