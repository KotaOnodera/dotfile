
##################
### Completion ###
##################
# https://qiita.com/ryuichi1208/items/2eef96debebb15f5b402

# プラグインを有効化する前に補完を初期化（compdef を使うプラグイン対策）
fpath=($ZSH_CONFIG $fpath)
autoload -Uz compinit
compinit -u

# 補完の選択を楽にする
zstyle ':completion:*' menu select

# キャッシュの利用による補完の高速化
zstyle ':completion::complete:*' use-cache true

# 補完候補に色つける
autoload -U colors ; colors ; zstyle ':completion:*' list-colors "${LS_COLORS}"

# 大文字・小文字を区別しない(大文字を入力した場合は区別する)
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# manの補完をセクション番号別に表示させる
zstyle ':completion:*:manuals' separate-sections true

# 補完候補を詰めて表示
setopt list_packed

# コマンドのスペルを訂正
setopt correct

# ビープ音を鳴らさない
setopt no_beep

# コマンドミスを修正
setopt correct

# -------------------------------------------------------------------------------------- #

##################
##### History ####
##################

# ヒストリの設定
export HISTFILE="${HISTFILE:-${ZDOTDIR:-$HOME}/.zsh_history}"
export HISTSIZE=10000
export SAVEHIST=$HISTSIZE

# ヒストリーに重複を表示しない
setopt histignorealldups

# 他のターミナルとヒストリーを共有
setopt share_history

# 直前のコマンドの重複を削除
setopt hist_ignore_dups

# すでにhistoryにあるコマンドは残さない
setopt hist_ignore_all_dups

# ヒストリに保存するときに余分なスペースを削除する
setopt hist_reduce_blanks

# 履歴をすぐに追加する
setopt inc_append_history

