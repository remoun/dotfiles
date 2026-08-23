# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export OMZ="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="spaceship"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $OMZ/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $OMZ/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $OMZ/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

# ssh-agent: starts automatically ssh-agent to set up and load credentials
# sudo: Easily prefix your current or previous commands with sudo by pressing esc twice.
plugins=(asdf bun command-not-found git git-flow git-prompt magic-enter node ssh-agent)

zstyle :omz:plugins:ssh-agent agent-forwarding yes

# https://docs.brew.sh/Shell-Completion needs to happen before sourcing OMZ.
if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

[[ -f $OMZ/oh-my-zsh.sh ]] && source $OMZ/oh-my-zsh.sh

# User configuration
[[ -s $HOME/code/z/z.sh ]] && source $HOME/code/z/z.sh

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
export EDITOR='vim'

# Tweak less' default behavior: ignore case, quit if one screen, support control chars, chop long lines, and disable de/init logic that clears screen.
export LESS="-iFRSX"

# Fix GPG access issues
export GPG_TTY=$TTY

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$HOME/.bun/bin:$HOME/.npm/bin:$PATH"

which thefuck >/dev/null && eval $(thefuck --alias)

# Disable globbing for regexps. Fixes 'no match found' errors when using an unquoted regex
alias ack='noglob ack'

# Make sure local env is loaded
[[ -f $HOME/.zshenv ]] && source $HOME/.zshenv

[[ -f "$HOME/.asdf/asdf.sh" ]] && source "$HOME/.asdf/asdf.sh"

# kubectl completion via https://kubernetes.io/docs/reference/kubectl/cheatsheet/
[[ -x /usr/local/bin/kubectl ]] && source <(kubectl completion zsh)

# iTerm2 integration.
[[ -e "${HOME}/.iterm2_shell_integration.zsh" ]] && source "${HOME}/.iterm2_shell_integration.zsh"

# Homebrew setup
[[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

# via https://coderwall.com/p/a8uxma/zsh-iterm2-osx-shortcuts
bindkey "[D" backward-word
bindkey "[C" forward-word
bindkey "^[a" beginning-of-line
bindkey "^[e" end-of-line

# tabtab (npm command completion)
# uninstall by removing these lines
[[ -s $HOME/.config/tabtab/__tabtab.zsh ]] && . $HOME/.config/tabtab/__tabtab.zsh || true

# via https://stackoverflow.com/a/42265848
export GPG_TTY=$(tty)

# lolcommits tweaks: Set delay to give camera a moment to warm up, fork capture process to not block git commit
# https://github.com/lolcommits/lolcommits/wiki/FAQ#help-im-getting-darkened-images-on-every-commit
export LOLCOMMITS_DELAY=2
export LOLCOMMITS_FORK=true

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# NPM aliases
alias nrd='npm run dev'
alias nrt='npm run test'
