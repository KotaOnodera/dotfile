# zsh プロンプト設定まとめ

- 対象ファイル: [`zsh/prompt.zsh`](zsh/prompt.zsh)
- 目的: ホスト/ユーザ/Git 状態と日時・カレントディレクトリを2行構成で表示し、右側に `vcs_info` の状態を重ねる設定。

## プロンプトエスケープ備忘（コメントより）

- ホスト: [`%M`](zsh/prompt.zsh:4) / [`%m`](zsh/prompt.zsh:5)
- カレントディレクトリ: フル [`%d`](zsh/prompt.zsh:6) / [`%~`](zsh/prompt.zsh:7)、相対 [`%C`](zsh/prompt.zsh:8) / [`%c`](zsh/prompt.zsh:9)
- ユーザ: [`%n`](zsh/prompt.zsh:10)、ユーザ種別: [`%#`](zsh/prompt.zsh:11)
- 直前コマンド終了ステータス: [`%?`](zsh/prompt.zsh:12)
- 日付: [`%D`](zsh/prompt.zsh:13) / [`%W`](zsh/prompt.zsh:14) / [`%w`](zsh/prompt.zsh:15)
- 時刻: [`%*`](zsh/prompt.zsh:16) / [`%T`](zsh/prompt.zsh:17) / [`%t`](zsh/prompt.zsh:18)

## 時刻リフレッシュ

- [`TMOUT`](zsh/prompt.zsh:21)=30 により 30 秒ごとに ALRM を発火。
- トラップ [`TRAPALRM`](zsh/prompt.zsh:22) で [`zle reset-prompt`](zsh/prompt.zsh:23) を実行し、表示中の時計を自動更新。

## Git プロンプト/補完連携

- [`source "$ZSH_CONFIG/git-prompt.sh"`](zsh/prompt.zsh:27) で Git の PS1 ヘルパーを読み込み、[`__git_ps1`](zsh/prompt.zsh:44) を利用可能に。
- 補完: `fpath` へ追加した上で [`zstyle ':completion:*:*:git:*' script ~/.zsh/git-completion.bash`](zsh/prompt.zsh:29) を指定し、[`compinit`](zsh/prompt.zsh:30) を初期化。
- ブランチ状態マーカー: [`GIT_PS1_SHOWDIRTYSTATE`](zsh/prompt.zsh:31)=true で未コミット状態を `__git_ps1` に反映。
- プロンプト内コマンド代入: [`setopt PROMPT_SUBST`](zsh/prompt.zsh:32) で `__git_ps1` を展開可能に。

## vcs_info の設定

- ロード: [`autoload -Uz vcs_info`](zsh/prompt.zsh:36) と [`setopt prompt_subst`](zsh/prompt.zsh:37)。
- 変更検知: [`zstyle ':vcs_info:git:*' check-for-changes true`](zsh/prompt.zsh:38)。
- 状態マーカー: ステージ済み [`stagedstr "%F{magenta}!"`](zsh/prompt.zsh:39)、未ステージ [`unstagedstr "%F{yellow}+"`](zsh/prompt.zsh:40)。
- 表示フォーマット: [`formats "%F{cyan}%c%u[%b]%f"`](zsh/prompt.zsh:41) でマーカーとブランチ名をシアンで表示、アクション時 [`actionformats '[%b|%a]'`](zsh/prompt.zsh:42)。
- フック: [`precmd(){ vcs_info }`](zsh/prompt.zsh:43) で毎プロンプト前に情報を更新。

## プロンプトレイアウト

- 左側 [`PROMPT`](zsh/prompt.zsh:44):
  - 1行目: シアンのホスト名 `%m`、グリーンのユーザ `%n`、続けて [`__git_ps1`](zsh/prompt.zsh:44) による `(ブランチ名)`（`GIT_PS1_SHOWDIRTYSTATE` で状態マーカー付き）。
  - 2行目: 日付 [`%D`](zsh/prompt.zsh:45)、時刻 [`%*`](zsh/prompt.zsh:45)、カレントディレクトリ [`%~`](zsh/prompt.zsh:45)、最後にマゼンタの `$`。
- 右側 [`RPROMPT`](zsh/prompt.zsh:46): [`${vcs_info_msg_0_}`](zsh/prompt.zsh:46) を表示し、`vcs_info` が生成したブランチ名と `+`/`!` マーカーを右寄せで出す。

## 使い方のポイント

- 時計を常に最新で見たい場合に便利（30 秒周期で自動更新）。
- 左は `__git_ps1`、右は `vcs_info` なので、Git 状態を二重表示したくなければ片方をコメントアウトして好みに合わせて調整可能。
