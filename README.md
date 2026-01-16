# dotfiles

macOS 開発環境の設定ファイル群

## 構成

```
.config/
├── aws/           # AWS CLI 設定
├── brew/          # Homebrew パッケージ管理
├── gh/            # GitHub CLI 設定
├── git/           # Git 設定
├── mise/          # ランタイムバージョン管理 (mise)
├── sheldon/       # Zsh プラグインマネージャ
├── vscode/        # Visual Studio Code 設定
├── wezterm/       # WezTerm ターミナル設定
├── zellij/        # Zellij ターミナルマルチプレクサ設定
├── zsh/           # Zsh 設定
└── zsh-abbr/      # Zsh 省略形設定
```

## 主要ツール

### ターミナル

- **WezTerm**: GPU アクセラレート対応ターミナル
  - カラースキーム: VibrantInk
  - Nerd Fonts アイコン対応のタブ表示
  - バッテリー・時刻表示のステータスバー

### シェル

- **Zsh** + **sheldon** (プラグインマネージャ)
- プラグイン:
  - zsh-autosuggestions (入力補完)
  - zsh-completions (補完拡張)
  - zsh-syntax-highlighting (構文ハイライト)
  - pure (プロンプトテーマ)
  - zsh-abbr (省略形展開)
  - zsh-git-fzf (Git + fzf 連携)
- **zoxide**: cd コマンドの拡張

### 開発ツール

- **mise**: 複数ランタイムのバージョン管理
  - Node.js, Python, Terraform, kubectl, neovim, gcloud, awscli, claude-code

### Homebrew パッケージ

#### CLI ツール
| ツール | 用途 |
|--------|------|
| bat | cat の代替 (シンタックスハイライト) |
| eza | ls の代替 (アイコン・Git 対応) |
| fd | find の代替 |
| ripgrep | grep の代替 |
| gh | GitHub CLI |
| sheldon | Zsh プラグインマネージャ |
| zoxide | cd の拡張 |
| mise | ランタイム管理 |

#### GUI アプリ
- WezTerm (ターミナル)
- Visual Studio Code (エディタ)
- Raycast (ランチャー)
- Rectangle (ウィンドウ管理)

### Git 設定

- エディタ: VS Code
- diff ツール: delta (side-by-side 表示)

### Zsh 省略形 (zsh-abbr)

よく使うコマンドの省略形:

| 省略形 | 展開後 |
|--------|--------|
| `gt` | `git` |
| `gta` | `git add` |
| `gtch` | `git checkout` |
| `tf` | `terraform` |
| `gc` | `gcloud` |
| `ls` | `eza --icons --git` |
| `vim` | `nvim` |

### Zellij

ターミナルマルチプレクサ。tmux 互換キーバインド対応。

主なキーバインド:
- `Ctrl+p`: ペインモード
- `Ctrl+t`: タブモード
- `Ctrl+b`: tmux モード

## セットアップ

```bash
# Homebrew インストール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# パッケージインストール
brew bundle --file=~/.config/brew/Brewfile

# VS Code 設定のシンボリックリンク
ln -s ~/.config/vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json

# Zshrc のシンボリックリンク
ln -s ~/.config/zsh/.zshrc ~/.zshrc
```

## Claude Code (Bedrock)

AWS Bedrock 経由で Claude Code を使用する設定:

```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1
export ANTHROPIC_MODEL='us.anthropic.claude-opus-4-5-20251101-v1:0'
```
