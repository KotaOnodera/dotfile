# Ghostty シェル統合 × pure テーマ 競合問題

## 発生日

2026-03-13

## 現象

Ghostty（およびcmux）でEnterを押すたびにディレクトリ表示が蓄積・増殖する。

## 原因

Ghosttyのシェル統合（`_ghostty_precmd`）と pure プロンプトテーマが **両方 `PS1` を書き換える** ため競合する。

- `_ghostty_precmd`: 毎回 `PS1` に OSC 133 マーク（`\e]133;A`, `\e]133;B`）を追加
- `pure`: 非同期で `PS1` を再構築（gitブランチ、ディレクトリ等）

Ghosttyのソースコード自体にもコメントあり:
> This code works incorrectly in the presence of a precmd or chpwd hook that prints.
> For example, **sindresorhus/pure prints an empty line on precmd**
>
> — ghostty-integration L105-106

## 対策

### Ghostty環境（非cmux）: 外科的アプローチ

`_ghostty_precmd` のみを `precmd_functions` から除去する。
`_ghostty_deferred_init` は実行させるため、以下の機能は維持される:

| 機能 | 状態 | 仕組み |
|------|------|--------|
| CWD報告 (`window-inherit-working-directory`) | 維持 | `chpwd_functions` 経由で報告 |
| カーソル形状変更 (vi mode) | 維持 | `zle-line-init` / `zle-keymap-select` フック |
| sudo連携 (terminfo引き継ぎ) | 維持 | `sudo` 関数ラッパー |
| SSH連携 (terminfo自動インストール) | 維持 | `ssh` 関数ラッパー |
| preexec時タイトル更新 (コマンド名表示) | 維持 | `_ghostty_preexec` |
| OSC 133 セマンティックプロンプト | **無効** | `_ghostty_precmd` が担当 |
| precmd時タイトル更新 (ディレクトリ表示) | **無効** | `_ghostty_precmd` に追加されている |

#### 実装

```zsh
# prompt.zsh 内
elif [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
    _fix_ghostty_pure_conflict() {
        precmd_functions=(${precmd_functions:#_ghostty_precmd})
        precmd_functions=(${precmd_functions:#_fix_ghostty_pure_conflict})
    }
    precmd_functions+=(_fix_ghostty_pure_conflict)
fi
```

**仕組み**: `_ghostty_deferred_init` は最初の precmd で実行され、自身を `_ghostty_precmd` に置換する。
`_fix_ghostty_pure_conflict` はその後に実行され、`_ghostty_precmd` を除去してから自身も除去する（1回限り）。

### cmux環境: 全除去アプローチ

`_ghostty_deferred_init` ごと阻止して全Ghosttyフックを除去する。
cmuxでは環境が異なるため、より保守的に全無効化している。

## 検討した代替案

| 代替案 | 不採用理由 |
|--------|-----------|
| `shell-integration = none` (Ghostty設定) | CWD報告・カーソル等の有用な機能まで全て失う |
| pureをやめてstarship等に移行 | 移行コストが高い。pureに問題があるわけではない |
| cmux式の全除去をGhosttyにも適用 | `window-inherit-working-directory` 等が動かなくなる |

## 関連ファイル

- `~/.config/zsh/prompt.zsh` — 修正箇所
- `~/.config/ghostty/config` — Ghostty設定（`shell-integration = detect`）
- `/Applications/Ghostty.app/.../ghostty-integration` — Ghosttyシェル統合スクリプト
