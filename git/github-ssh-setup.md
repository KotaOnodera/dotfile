# GitHubでSSH接続を設定する手順

## 1. SSHキーの生成

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

- パスフレーズの設定を求められる（任意）
- デフォルトでは `~/.ssh/id_ed25519`（秘密鍵）と `~/.ssh/id_ed25519.pub`（公開鍵）が生成される

## 2. SSH Agentの起動とキーの登録

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

## 3. 公開鍵をGitHubに登録

```bash
# 公開鍵をクリップボードにコピー（macOS）
pbcopy < ~/.ssh/id_ed25519.pub
```

1. GitHub → Settings → SSH and GPG keys → New SSH key
2. Titleに識別名を入力
3. Keyにコピーした公開鍵を貼り付け
4. Add SSH key

## 4. 接続テスト

```bash
ssh -T git@github.com
```

成功すると以下のメッセージが表示される：

```
Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

## 5. SSHでリポジトリをクローン

```bash
git clone git@github.com:username/repository.git
```

既存のHTTPSリモートをSSHに変更する場合：

```bash
git remote set-url origin git@github.com:username/repository.git
```
