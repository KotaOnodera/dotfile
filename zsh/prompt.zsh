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

# pure テーマ: Git ブランチ名を黄色で表示
zstyle ':prompt:pure:git:branch' color yellow

# pureの2行目(プロンプト記号)を、ユーザー名+日時+`$`表示に置き換える
export PURE_PROMPT_SYMBOL='%f[%F{green}%n%f] %D %* %F{magenta}$%f'

# --- Ghostty シェル統合 × pure テーマ 競合対策 ---
# 詳細: ~/.config/zsh/ghostty-pure-conflict.md

# cmux環境: ghosttyフックを全て除去（deferred_initごと阻止）
if [[ -n "${CMUX_WORKSPACE_ID:-}" ]]; then
	autoload -Uz add-zsh-hook
	add-zsh-hook -d precmd _ghostty_deferred_init 2>/dev/null || true
	add-zsh-hook -d precmd _ghostty_precmd 2>/dev/null || true
	add-zsh-hook -d preexec _ghostty_preexec 2>/dev/null || true
	precmd_functions=(${precmd_functions:#_ghostty_deferred_init})
	precmd_functions=(${precmd_functions:#_ghostty_precmd})
	preexec_functions=(${preexec_functions:#_ghostty_preexec})

# Ghostty環境(非cmux): _ghostty_precmdのみ除去（外科的アプローチ）
# _ghostty_deferred_initは残すため、CWD報告・カーソル・sudo/SSH連携は維持される
elif [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
	_fix_ghostty_pure_conflict() {
		precmd_functions=(${precmd_functions:#_ghostty_precmd})
		precmd_functions=(${precmd_functions:#_fix_ghostty_pure_conflict})
	}
	precmd_functions+=(_fix_ghostty_pure_conflict)
fi

# # Added by Antigravity
# export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
