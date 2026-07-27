# dotfiles

macOS 開発環境の設定ファイルと、安全に復元・検証するためのスクリプトを管理するリポジトリです。通常の復元先は `~/.config` です。`latest` を指定するツールは実行時点の最新版を導入するため、同一バージョンの完全な再現を約束するものではありません。

## 構成

```
.config/
├── bootstrap                 # Brewfile・mise・管理対象リンクを安全に再適用
├── verify                    # 設定を変更しない読み取り専用の検証
├── manifests/links.tsv       # 外部へ作成するリンクの唯一の定義
├── brew/                     # Homebrew パッケージ管理
├── ghostty/                  # Ghostty の設定
├── mise/                     # ランタイムバージョン管理
├── vscode/                   # Visual Studio Code 設定
├── zsh/                      # Zsh 設定
└── git/                      # Git 設定
```

このリポジトリにある XDG 設定（例: `ghostty/`、`mise/`、`vscode/`、`zsh/`）は、リポジトリ自身が `~/.config` にあることを前提に、そのまま管理します。外部に作成するシンボリックリンクは `manifests/links.tsv` の次の 3 件だけです。

- `~/.zshrc` → `zsh/.zshrc`
- `~/.gitconfig` → `git/.gitconfig`
- `~/Library/Application Support/Code/User/settings.json` → `vscode/settings.json`

### ターミナル

Ghostty の設定はこのリポジトリで管理します。ただし、Ghostty アプリケーション自体は Brewfile の管理対象外です。必要に応じて各自で導入してください。既存の WezTerm は互換性のため Brewfile に残しています。

### 主な開発ツール

- **Zsh** + **sheldon**: シェルとプラグイン管理
- **mise**: Node.js、Python、Terraform、kubectl などのランタイム管理
- **Homebrew**: CLI ツールと既存アプリケーションの宣言的な同期
- **VS Code**: エディタ設定

## 復元前の前提条件

1. Homebrew と `mise` を、公式の案内に従ってあらかじめ導入します。
2. このリポジトリを通常の場所へ clone します。

   ```bash
   git clone <repository-url> ~/.config
   cd ~/.config
   ```

3. Homebrew が外部 tap の信頼を求めた場合は、内容を確認した上で手動で対応します。bootstrap は tap の信頼、Homebrew の導入、`sudo` 操作、ダウンロード用 `curl` コマンドを自動実行しません。

Homebrew の同期には Brew Bundle を使用します。Brew Bundle は不足している依存関係を導入するだけでなく、既に導入済みのパッケージを更新する場合があります。実行前に更新の影響を確認してください。

## セットアップと安全な再適用

通常は次を実行します。

```bash
cd ~/.config
./bootstrap
```

`bootstrap` は、まずすべてのリンク定義と競合を検査します。検査に失敗した場合は、Brew Bundle、mise、バックアップ、リンク作成を実行しません。問題なく検査できた後に、Brewfile、mise、3 件の管理対象リンクを再適用します。

### `bootstrap` のオプション

```text
./bootstrap [--dry-run] [--link-only] [--skip-brew] [--skip-mise] [--backup]
```

- `--dry-run`: 検査と予定操作の表示だけを行います。外部コマンド、ファイル移動、ディレクトリ作成、リンク作成は行いません。
- `--link-only`: Homebrew と mise を実行せず、管理対象リンクだけを処理します。
- `--skip-brew`: Brew Bundle の同期を省略します。
- `--skip-mise`: mise の同期を省略します。
- `--backup`: 通常ファイル、ディレクトリ、または異なるリンクが管理対象のリンク先と競合した場合、それらを退避してからリンクを作成します。退避先は既定で `~/.dotfiles-backups/<timestamp>-<pid>/` です。既存のバックアップを上書きすることはありません。

`--backup` を付けない限り、競合する既存ファイルや異なるリンクは保護され、処理は失敗します。正しいリンクがすでにある場合は何も変更しないため、再実行しても安全です。

旧来の入口である `./setup-mac.sh` も互換ラッパーとして残しており、引数をそのまま `./bootstrap` へ渡します。新しい手順では `./bootstrap` を使用してください。

## 検証

復元後や変更後は、読み取り専用の検証を実行します。

```bash
cd ~/.config
./verify
```

`verify` は Git リポジトリ、リンク定義と source、3 件の管理リンク、Brewfile、mise 構成を確認します。パッケージの導入・更新、リンク作成、バックアップ作成は行いません。

mise の確認は、`verify` を呼び出したシェルで mise が有効化されていることも検証します。通常は、mise を設定した**対話的な Zsh** から `./verify` を実行してください。CI など意図的に非対話で実行し、シェル有効化が検証対象外である場合に限り、`./verify --skip-mise` で mise の診断だけを省略できます。これは mise の有効化確認を弱めるためではなく、呼び出し側のシェル設定を別途管理する自動化のための境界です。

```text
./verify [--skip-brew] [--skip-mise]
```

- `--skip-brew`: Brew Bundle の状態確認を省略します。
- `--skip-mise`: mise の診断を省略します。

たとえばリンクだけを確認したい場合は、次を実行します。

```bash
./verify --skip-brew --skip-mise
```

## 回帰テスト

一時 `HOME` とコマンドスタブを使うため、テストはこの Mac の設定やパッケージを変更しません。

```bash
cd ~/.config
./tests/run.sh
```

## Claude Code (Bedrock)

AWS Bedrock 経由で Claude Code を使用する設定例です。

```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1
export ANTHROPIC_MODEL='us.anthropic.claude-opus-4-5-20251101-v1:0'
```
