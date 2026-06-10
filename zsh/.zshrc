# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                          MONKEY DOTS - ZSH                                   ║
# ║             Adapted from Gentleman.Dots .zshrc                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

# Detect Termux (kept for parity, even though Monkey.Dots doesn't officially support it)
IS_TERMUX=0
if [[ -n "$TERMUX_VERSION" ]] || [[ -d "/data/data/com.termux" ]]; then
    IS_TERMUX=1
fi

# Set PATH based on platform
if [[ $IS_TERMUX -eq 1 ]]; then
    export PATH="$PREFIX/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
else
    export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.cargo/bin:$HOME/.volta/bin:$HOME/.bun/bin:/usr/local/bin:$HOME/.config:$HOME/.cargo/bin:/usr/local/lib/*:$PATH"
fi

# Default editor
export EDITOR="nvim"
export VISUAL="nvim"

if [[ $- == *i* ]]; then
    # Commands to run in interactive sessions can go here
fi

export LS_COLORS="di=38;5;67:ow=48;5;60:ex=38;5;132:ln=38;5;144:*.tar=38;5;180:*.zip=38;5;180:*.jpg=38;5;175:*.png=38;5;175:*.mp3=38;5;175:*.wav=38;5;175:*.txt=38;5;223:*.sh=38;5;132"
if [[ "$(uname)" == "Darwin" ]]; then
  alias ls='ls --color=auto'
else
  alias ls='gls --color=auto'
fi

# Homebrew setup (skip on Termux)
if [[ $IS_TERMUX -eq 0 ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            BREW_BIN="/opt/homebrew/bin"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            BREW_BIN="/usr/local/bin"
        fi
    else
        BREW_BIN="/home/linuxbrew/.linuxbrew/bin"
    fi

    if [[ -n "$BREW_BIN" && -f "$BREW_BIN/brew" ]]; then
        eval "$($BREW_BIN/brew shellenv)"
    fi
fi

# Zsh plugins - different paths for Termux vs Homebrew
if [[ $IS_TERMUX -eq 1 ]]; then
    [[ -f "$PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]] && source "$PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
    [[ -f "$PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    [[ -f "$PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    [[ -f "$PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme" ]] && source "$PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme"
else
    [[ -f "$(dirname $BREW_BIN)/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]] && source "$(dirname $BREW_BIN)/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
    [[ -f "$(dirname $BREW_BIN)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$(dirname $BREW_BIN)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    [[ -f "$(dirname $BREW_BIN)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$(dirname $BREW_BIN)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    [[ -f "$(dirname $BREW_BIN)/share/powerlevel10k/powerlevel10k.zsh-theme" ]] && source "$(dirname $BREW_BIN)/share/powerlevel10k/powerlevel10k.zsh-theme"
fi

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_DEFAULT_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

WM_VAR="/$TMUX"
WM_CMD="tmux"

function start_if_needed() {
    if [[ $- == *i* ]] && [[ -z "${WM_VAR#/}" ]] && [[ -t 1 ]]; then
        exec $WM_CMD
    fi
}

# alias
alias fzfbat='fzf --preview="bat --theme=gruvbox-dark --color=always {}"'
alias fzfnvim='nvim $(fzf --preview="bat --theme=gruvbox-dark --color=always {}")'

# plugins
plugins=(
  command-not-found
)

# Oh My Zsh is installed by the installer. If for some reason it's
# missing (e.g. --no-brew on a fresh box, or Windows-native), skip
# the source and continue with starship/fzf/zoxide/atuin.
if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
else
    print -r -- "[monkey] $ZSH/oh-my-zsh.sh not found; running with starship-only" >&2
fi

export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
[[ -f "$(dirname $BREW_BIN)/bin/carapace" ]] && source <(carapace _carapace)

eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
[[ -f "$HOME/.local/share/atuin/init.zsh" ]] && eval "$(atuin init zsh)"

# Starship (takes precedence over p10k when installed)
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
else
    # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi

start_if_needed
