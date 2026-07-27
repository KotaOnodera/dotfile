###############################
### environmental variables ###
###############################

export LANG=ja_JP.UTF-8
export LSCOLORS=gxfxcxdxbxegedabagacad
export CLICOLOR=1
export LSCOLORS=DxGxcxdxCxegedabagacad
export ZSH_CONFIG="${ZDOTDIR:-$HOME}/.config/zsh"
export EDITOR=nvim

# eza 用の最低限色 (LS_COLORS)
# ディレクトリ=シアン, 実行ファイル=緑, シンボリックリンク=マゼンタ
export LS_COLORS="di=01;36:ex=01;32:ln=01;35"

# Claude CodeをBedrock経由で利用する
# Enable Bedrock integration
# export CLAUDE_CODE_USE_BEDROCK=1
# export AWS_REGION=ap-northeast-1
# export ANTHROPIC_MODEL='global.anthropic.claude-opus-4-6-v1'
# export AWS_BEARER_TOKEN_BEDROCK=""

# -------------------------------------------------------------------------------------- #


##################
##### Pathes #####
##################

export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

# # for gcloud command
# export CLOUDSDK_PYTHON=/usr/bin/python3

# -------------------------------------------------------------------------------------- #


##################
##### Source #####
##################

# Zshrcのsourceの読み込み
source "$ZSH_CONFIG/completion.zsh" > /dev/null

# プラグインを有効化
eval "$(sheldon source)"

# mise
# ref: https://mise.jdx.dev/getting-started.html#activate-mise
if [ -d "$HOME/.config/mise" ]; then
	eval "$(mise activate zsh)"
fi

# zcxideの置換
if [[ $- == *i* ]]; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# miseでインストールしているpureのあとに読み込み
source "$ZSH_CONFIG/prompt.zsh"
