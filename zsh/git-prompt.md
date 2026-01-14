# git-prompt.sh の概要と使い方

## 目的
`.config/zsh/git-prompt.sh` は Git リポジトリ内でプロンプトにブランチ名や状態を表示するためのスクリプトです。`__git_ps1` 関数を用いて、ブランチ名・変更有無・stash・未追跡・upstream 乖離などを PS1 に埋め込みます（出典: [`git-prompt.sh`](.config/zsh/git-prompt.sh:1)）。

## 主な機能

- ブランチ名表示: 常に現在ブランチ名またはデタッチド HEAD を表示
- 変更状態表示: `GIT_PS1_SHOWDIRTYSTATE` 有効時に unstaged `*` / staged `+` を付与 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:38))
- stash 状態: `GIT_PS1_SHOWSTASHSTATE` で `$` 表示 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:44))
- 未追跡ファイル: `GIT_PS1_SHOWUNTRACKEDFILES` で `%` 表示 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:48))
- upstream 乖離: `GIT_PS1_SHOWUPSTREAM` で `<`(behind)/`>`(ahead)/`<>`(diverged)/`=`(同期) を表示、`verbose` でコミット数や upstream 名も表示 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:55))
- 進行中の操作: rebase/merge/cherry-pick/bisect などを `|REBASE` 等で表示 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:78))
- コンフリクト通知: `GIT_PS1_SHOWCONFLICTSTATE=yes` で `|CONFLICT` 表示 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:87))
- スパースチェックアウト通知: `core.sparseCheckout=true` 時に `|SPARSE` 表示。`GIT_PS1_COMPRESSSPARSESTATE` で `?` に短縮、`GIT_PS1_OMITSPARSESTATE` で非表示 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:82))
- カラー表示: `GIT_PS1_SHOWCOLORHINTS` で dirty 状態などを色付け ([`git-prompt.sh`](.config/zsh/git-prompt.sh:101))
- 無視パス回避: `GIT_PS1_HIDE_IF_PWD_IGNORED` でカレントが ignore 対象なら表示しない ([`git-prompt.sh`](.config/zsh/git-prompt.sh:105))

## 導入手順 (zsh 前提)

1. スクリプトを source: `source ~/.config/zsh/git-prompt.sh` を `~/.config/zsh/.zshrc` 等に追記 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:10)).
2. `setopt PROMPT_SUBST` を有効化して PS1 を設定:

   ```zsh
   setopt PROMPT_SUBST
   PROMPT='[%n@%m %~$(__git_ps1 " (%s)")]$ '
   ```

   - `(%s)` 部分に Git 状態文字列が挿入されます ([`git-prompt.sh`](.config/zsh/git-prompt.sh:14)).
3. もしくは precmd フックで高速化 (zsh 推奨例):

   ```zsh
   setopt PROMPT_SUBST
   precmd() { __git_ps1 "%n" ":%~$ " "|%s" }
   ```

   - `precmd` で PS1 を動的に組み立てる例 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:27)).

## よく使う環境変数オプション

- `GIT_PS1_SHOWDIRTYSTATE=1` : unstaged/staged を `*`/`+` 表示
- `GIT_PS1_SHOWSTASHSTATE=1` : stash ありで `$` 表示
- `GIT_PS1_SHOWUNTRACKEDFILES=1` : 未追跡で `%` 表示
- `GIT_PS1_SHOWUPSTREAM="auto"` : upstream 差分を `<`, `>`, `<>`, `=` で表示
  - `GIT_PS1_SHOWUPSTREAM="auto verbose name"` でコミット数と upstream 名も表示 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:55))
- `GIT_PS1_STATESEPARATOR=" "` : 状態セパレータ変更 (デフォルト: 半角スペース) ([`git-prompt.sh`](.config/zsh/git-prompt.sh:74))
- `GIT_PS1_SHOWCONFLICTSTATE=yes` : コンフリクト中に `|CONFLICT`
- `GIT_PS1_COMPRESSSPARSESTATE=1` : スパース表示を `?` に短縮
- `GIT_PS1_OMITSPARSESTATE=1` : スパース表示を抑制
- `GIT_PS1_HIDE_IF_PWD_IGNORED=1` : ignore 対象ディレクトリで表示しない
- `GIT_PS1_SHOWCOLORHINTS=1` : 色付き状態表示 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:101))

## 動作概要 (__git_ps1)

- Git 管理下にいるかを `git rev-parse` で判定し、非 Git ディレクトリなら何も表示しません ([`git-prompt.sh`](.config/zsh/git-prompt.sh:409)).
- リポジトリ状態を収集: rebase/merge/cherry-pick/bisect などの進行状態、dirty/staged/stash/untracked、sparse checkout、upstream 乖離、コンフリクトを確認 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:446)).
- `GIT_PS1_SHOWCOLORHINTS` が有効なら色コードを付与 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:575)).
- `pcmode` (PROMPT_COMMAND/precmd 経由) の場合、PS1 を組み立ててセット。通常は `printf_format` に従い `(%s)` などに状態文字列を埋め込む ([`git-prompt.sh`](.config/zsh/git-prompt.sh:582)).

## トラブルシュート

- プロンプトに出ない: `setopt PROMPT_SUBST` が有効か、`__git_ps1` 呼び出しが PS1 または precmd 内にあるかを確認。
- 色が崩れる: `GIT_PS1_SHOWCOLORHINTS` を無効化するか、ターミナルのカラー設定を確認。
- タイミングで表示が遅い: precmd フックで使うと再描画負荷が下がる場合があります ([`git-prompt.sh`](.config/zsh/git-prompt.sh:19)).

## 参考

- 元の補完・プロンプトは Git 公式の `contrib/completion/git-prompt.sh` 系スクリプトに基づく実装です。ライセンス: GPLv2 ([`git-prompt.sh`](.config/zsh/git-prompt.sh:3)).
