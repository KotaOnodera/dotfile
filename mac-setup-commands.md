# Macセットアップ関連コマンドレポート (期間: 2026-01-10〜2026-01-13 JST)

## 1. 概要

- 対象期間: 2026-01-10 00:00 JST 以降。本日時点で取得できた履歴は 2026-01-13 JST のみ。
- データソース: zsh 履歴 [`~/.zsh_history`](.zsh_history:1)。
- 目的: Mac 初期セットアップに関わる実行コマンドの抽出、設定ファイルとの紐付け、使用方法の解説。

## 2. コマンド一覧 (JST)

| 日時 (JST) | コマンド | 目的/補足 | 出典 |
| --- | --- | --- | --- |
| 時刻情報なし | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` | Homebrew 初期インストール | [`~/.zsh_history`](.zsh_history:5) |
| 時刻情報なし | `brew list` | インストール済み Homebrew パッケージの確認 | [`~/.zsh_history`](.zsh_history:6) |
| 2026-01-13 12:02:18 | `echo "${ZDOTDIR:-$HOME}/.config/zsh/"` | zsh 設定ディレクトリの確認 | [`~/.zsh_history`](.zsh_history:7) |
| 2026-01-13 12:08:19 | `source ~/.zshrc` | zsh 設定の再読み込み | [`~/.zsh_history`](.zsh_history:8) |
| 2026-01-13 13:42:48〜13:52:07 | `abbr`, `abbr --version`, `asdf list zsh-abbr`, `asdf plugin list` | シェル短縮コマンド/プラグイン状態確認 | [`~/.zsh_history`](.zsh_history:9)〜[`~/.zsh_history`](.zsh_history:16) |
| 2026-01-13 13:55:14〜14:02:22 | `ls -aFl`, `cd .config/zsh`, `source ~/.zshrc` | zsh 設定ディレクトリ移動と設定再読み込み | [`~/.zsh_history`](.zsh_history:21)〜[`~/.zsh_history`](.zsh_history:24) |
| 2026-01-13 14:24:23〜14:39:11 | `mkdir ../vscode`, `cp ~/Library/Application\ Support/code/User/settings.json .`, `ln -s settings.json ~/Library/Application\ Support/code/User/` ほか symlink 再作成 | VS Code 設定 (`settings.json`) をリポジトリ配下へ集約し、ユーザ設定へシンボリックリンクを張り直し | [`~/.zsh_history`](.zsh_history:27)〜[`~/.zsh_history`](.zsh_history:71) |
| 2026-01-13 14:51:57〜14:52:05 | `ls -aFl ~`, `ls -aFl /Users/kotaonodera` | ホーム直下の状態確認 | [`~/.zsh_history`](.zsh_history:72)〜[`~/.zsh_history`](.zsh_history:73) |

> 備考: 上記時刻は履歴のエポック秒 (UTC) を JST (+9) へ換算。タイムスタンプが付かないエントリは「時刻情報なし」としている。

## 3. トピック別サマリと設定ファイル紐付け
### 3-1. Homebrew/パッケージ管理

- Bootstrap: Homebrew インストール [`~/.zsh_history`](.zsh_history:5)。
- セットアップスクリプト: [`setup-mac.sh`](setup-mac.sh:1) で cask/app (Visual Studio Code, WezTerm, Raycast, Rectangle) と CLI (asdf, git, gh, bat, sheldon, mise, zsh-abbr) をインストールする手順を定義。
- Brewfile (自動化/再現性): [`.config/sheldon/Brewfile`](.config/sheldon/Brewfile:1) に tap, brew, cask, VS Code 拡張一覧を記録。`brew bundle --file ~/.config/sheldon/Brewfile` で再適用可能。

### 3-2. シェル環境 (zsh + sheldon + abbreviations)

- zsh 基本設定: [`~/.config/zsh/.zshrc`](.config/zsh/.zshrc:5) でロケール/色設定、`ZSH_CONFIG` 定義、`sheldon` プラグイン読み込み、`mise activate` 実行、補完/プロンプト読み込みを実施。
- 履歴・補完調整: [`~/.config/zsh/completion.zsh`](.config/zsh/completion.zsh:1) で履歴共有、重複抑止、スペル訂正、補完色などを設定。
- プラグイン管理: [`~/.config/sheldon/plugins.toml`](.config/sheldon/plugins.toml:13) で `zsh-autosuggestions`, `zsh-completions`, `pure`, `zsh-abbr`, `zsh-syntax-highlighting` 等を管理。
- 略語定義: [`~/.config/zsh-abbr/user-abbreviations`](.config/zsh-abbr/user-abbreviations:1) に `ls`→`ls -aFl`, `cp -i`, `cat`→`bat` のほか gcloud / terraform / git 系ショートカットを定義。履歴上の `abbr` / `abbr --version` 実行はこれらの定義確認と整合。
- Git 補助: [`~/.config/zsh/git-completion.bash`](.config/zsh/git-completion.bash:1), [`~/.config/zsh/git-prompt.sh`](.config/zsh/git-prompt.sh:1) を同梱 (補完・プロンプト用)。

### 3-3. VS Code 設定同期

- 作業内容: 14:24〜14:39 JST に `settings.json` をリポジトリに集約し、`~/Library/Application Support/Code/User` 配下へシンボリックリンクを複数回張り直し（エラー復旧含む）。参照: [`~/.zsh_history`](.zsh_history:27)〜[`~/.zsh_history`](.zsh_history:71)。
- 恒久設定: [`setup-mac.sh`](setup-mac.sh:21) で `ln -s ~/.config/vscode/settings.json` をユーザ設定へ張る運用を明示。
- 拡張セット: Brewfile 内の `vscode "..."` 群で拡張を列挙し再現性を担保。

### 3-4. ツールチェーン/バージョン管理

- mise: [`~/.config/mise/config.toml`](.config/mise/config.toml:1) で `neovim`, `terraform` を latest 運用 (他はコメントアウト)。zshrc の `eval "$(mise activate bash)"` でシェルに反映。
- asdf: 履歴中の `asdf list zsh-abbr` / `asdf plugin list` によりプラグイン状況を確認 (セットアップチェック)。

## 4. 推奨フォローアップ

1) [`setup-mac.sh`](setup-mac.sh:1) を最新状態に合わせて見直し (Brewfile と整合性確認)。
2) VS Code 設定同期の一次作業が完了しているため、`~/Library/Application Support/Code/User/settings.json` がシンボリックリンクであることを再確認。
3) 履歴に時刻が含まれない初期コマンドもあるため、必要なら `HISTTIMEFORMAT` を有効化して再取得を推奨。

---
生成: 2026-01-13 JST
