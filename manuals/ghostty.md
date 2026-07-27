# Ghostty 操作マニュアル

## ペイン（分割）操作

| キー | 操作 |
|---|---|
| `Opt + Enter` | 下に分割 |
| `Opt + Shift + Enter` | 右に分割 |
| `Opt + ←↑↓→` | ペイン間の移動 |
| `Opt + Shift + ←↑↓→` | ペインのリサイズ |
| `Cmd + W` | 現在のペインを閉じる |

## タブ操作

| キー | 操作 |
|---|---|
| `Cmd + T` | 新しいタブ |
| `Cmd + Shift + ]` | 次のタブ |
| `Cmd + Shift + [` | 前のタブ |

## Quick Terminal

| キー | 操作 |
|---|---|
| `Cmd + Shift + T` | Quick Terminal の表示/非表示（右からスライド） |

## クリップボード

| 操作 | 説明 |
|---|---|
| テキスト選択 | 自動でコピー（copy-on-select） |
| `Cmd + V` | 貼り付け |

## レイアウトスクリプト

`~/.config/ghostty/scripts/` にAppleScriptのプリセットがある。

### dev-layout（開発用4ペイン）

```bash
osascript ~/.config/ghostty/scripts/dev-layout.scpt
```

```
┌──────────┬───────────────┐
│  yazi    │  cage claude  │
│  (40%)   │    (60%)      │
├──────────┤               │
│  gitui   ├───────────────┤
│          │  shell        │
└──────────┴───────────────┘
```

- 左上: yazi（ファイラー）
- 左下: gitui
- 右上: cage claude
- 右下: シェル（フォーカス）

### simple-split（シンプル2ペイン）

```bash
osascript ~/.config/ghostty/scripts/simple-split.scpt
```

```
┌─────────────┬─────────────┐
│   shell     │   shell     │
│   (50%)     │   (50%)     │
└─────────────┴─────────────┘
```

## 設定ファイル

| ファイル | 説明 |
|---|---|
| `~/.config/ghostty/config` | メイン設定 |
| `~/.config/ghostty/scripts/` | レイアウトスクリプト |
