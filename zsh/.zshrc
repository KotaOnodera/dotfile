###############################
### environmental variables ###
###############################

export LANG=ja_JP.UTF-8
export LSCOLORS=gxfxcxdxbxegedabagacad
export CLICOLOR=1
export LSCOLORS=DxGxcxdxCxegedabagacad
export PATH="/opt/homebrew/bin:$PATH"
export ZSH_CONFIG="${ZDOTDIR:-$HOME}/.config/zsh"

# -------------------------------------------------------------------------------------- #


##################
##### Pathes #####
##################


# # The next line updates PATH for the Google Cloud SDK.
# if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi

# # The next line enables shell command completion for gcloud.
# if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

# pyenv
# export PYENV_ROOT="$HOME/.pyenv"
# export PATH="$PYENV_ROOT/bin:$PATH"
# eval "$(pyenv init --path)"
# eval "$(pyenv init -)"

# # for gcloud command
# export CLOUDSDK_PYTHON=/usr/bin/python3

# -------------------------------------------------------------------------------------- #


##################
##### Source #####
##################

# プラグインを有効化
eval "$(sheldon source)"

# mise
# ref: https://mise.jdx.dev/getting-started.html#activate-mise
if [ -d "$HOME/.config/mise" ]; then
	eval "$(mise activate bash)"
fi

# Zshrcのsourceの読み込み
source "$ZSH_CONFIG/completion.zsh" > /dev/null
source "$ZSH_CONFIG/prompt.zsh" 

# -------------------------------------------------------------------------------------- #
