##################
##### Prompt #####
##################
# %M    ホスト名
# %m    ホスト名
# %d    カレントディレクトリ(フルパス)
# %~    カレントディレクトリ(フルパス2)
# %C    カレントディレクトリ(相対パス)
# %c    カレントディレクトリ(相対パス)
# %n    ユーザ名
# %#    ユーザ種別
# %?    直前のコマンドの戻り値
# %D    日付(yy-mm-dd)
# %W    日付(yy/mm/dd)
# %w    日付(day dd)
# %*    時間(hh:flag_mm:ss)
# %T    時間(hh:mm)
# %t    時間(hh:mm(am/pm))

# 現在時刻を 30 秒ごとに再描画（ALRM トラップで zle reset-prompt）
TMOUT=30
TRAPALRM(){
	zle reset-prompt
}

# Git 補完と __git_ps1 用の設定
# git-completion の関数探索パス追加
fpath=(~/.zsh $fpath)
# 補完初期化
autoload -Uz compinit && compinit -u
# __git_ps1 に dirty/clean 状態を表示
GIT_PS1_SHOWDIRTYSTATE=true
# プロンプト内コマンド代入を有効化
setopt PROMPT_SUBST

export PROMPT='[%F{green}%n%f] %D %* %F{magenta}$%f '

# # Added by Antigravity
# export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
