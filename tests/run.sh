#!/bin/bash

# Regression coverage for bootstrap and verify.  Every test uses a temporary
# HOME and command doubles, so it never changes this machine's dotfiles.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tests.XXXXXX")
test_root=$(cd -L "$test_root" && pwd -L)
passed=0
failed=0

cleanup() {
  if [ -n "${test_child_pid:-}" ]; then
    kill "$test_child_pid" 2>/dev/null || true
    wait "$test_child_pid" 2>/dev/null || true
  fi
  rm -rf "$test_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
  echo "FAIL: $*" >&2
  return 1
}

assert_path_is_symlink() {
  local path=$1
  [ -L "$path" ] || fail "expected symlink: $path"
}

assert_path_points_to() {
  local path=$1
  local target=$2
  assert_path_is_symlink "$path"
  [ "$path" -ef "$target" ] || fail "expected $path to resolve to $target"
}

assert_file_contains() {
  local path=$1
  local expected=$2
  [ -f "$path" ] || fail "expected file: $path"
  grep -F -- "$expected" "$path" >/dev/null || fail "expected $path to contain: $expected"
}

assert_path_absent() {
  local path=$1
  [ ! -e "$path" ] && [ ! -L "$path" ] || fail "expected path to be absent: $path"
}

assert_file_empty() {
  local path=$1
  [ -f "$path" ] || fail "expected file: $path"
  [ ! -s "$path" ] || fail "expected file to be empty: $path"
}

test_readme_documents_bootstrap_restore_workflow() {
  local required_text

  for required_text in \
    './bootstrap' \
    './verify' \
    './verify --skip-mise' \
    '--dry-run' \
    '--backup' \
    'Ghostty' \
    'WezTerm' \
    'Brewfile の管理対象外' \
    'Ghostty アプリケーション自体は Brewfile の管理対象外です。' \
    '既存の WezTerm は互換性のため Brewfile に残しています。' \
    '~/.config' \
    '対話的な Zsh' \
    'Homebrew と `mise` を、公式の案内に従ってあらかじめ導入します。' \
    '外部 tap の信頼' \
    '手動' \
    '外部 tap の信頼を求めた場合は、内容を確認した上で手動で対応します。' \
    'Brew Bundle' \
    '更新' \
    '既に導入済みのパッケージを更新する場合があります。' \
    'latest' \
    '完全な再現を約束するものではありません。' \
    'curl' \
    'sudo' \
    'tap の信頼、Homebrew の導入、`sudo` 操作、ダウンロード用 `curl` コマンドを自動実行しません。' \
    './bootstrap [--dry-run] [--link-only] [--skip-brew] [--skip-mise] [--backup]' \
    './verify [--skip-brew] [--skip-mise]' \
    '競合する既存ファイルや異なるリンクは保護され、処理は失敗します。'; do
    assert_file_contains "$repo_root/README.md" "$required_text" || return 1
  done
}

assert_command_exit_code() {
  local expected=$1 stdout_path=$2 stderr_path=$3 actual
  shift 3

  if "$@" >"$stdout_path" 2>"$stderr_path"; then
    actual=0
  else
    actual=$?
  fi
  [ "$actual" -eq "$expected" ] || fail "expected exit $expected, got $actual: $*"
}

assert_command_fails() {
  if "$@"; then
    fail "expected command to fail: $*"
  fi
}

run_test() {
  local name=$1
  if "$name"; then
    passed=$((passed + 1))
    echo "PASS: $name"
  else
    failed=$((failed + 1))
    echo "FAIL: $name" >&2
  fi
}

new_home() {
  local name=$1
  local home="$test_root/$name/home"
  mkdir -p "$home"
  printf '%s\n' "$home"
}

new_dotfiles_root() {
  local name=$1
  local root="$test_root/$name/dotfiles-root"
  mkdir -p "$root/brew" "$root/manifests" "$root/mise" "$root/sources"
  printf '%s\n' "$root"
}

make_command_doubles() {
  local name=$1
  local bin="$test_root/$name/bin"
  mkdir -p "$bin"

  cat >"$bin/brew" <<'EOF'
#!/bin/bash
set -eu
: "${TEST_LOG:?TEST_LOG must be set}"
printf 'brew cwd=%s argv=' "$PWD" >>"$TEST_LOG"
for argument in "$@"; do
  printf '[%s]' "$argument" >>"$TEST_LOG"
done
printf '\n' >>"$TEST_LOG"
exit "${MOCK_BREW_EXIT:-0}"
EOF
  cat >"$bin/mise" <<'EOF'
#!/bin/bash
set -eu
: "${TEST_LOG:?TEST_LOG must be set}"
printf 'mise cwd=%s argv=' "$PWD" >>"$TEST_LOG"
for argument in "$@"; do
  printf '[%s]' "$argument" >>"$TEST_LOG"
done
printf '\n' >>"$TEST_LOG"
exit "${MOCK_MISE_EXIT:-0}"
EOF
  chmod +x "$bin/brew" "$bin/mise"
  printf '%s\n' "$bin"
}

relative_target_from_home() {
  local home=$1
  local target=$2
  local target_dir
  local cursor=$home
  local prefix=

  home=$(cd -P "$home" && pwd)
  target_dir=$(cd -P "$(dirname "$target")" && pwd)
  target="$target_dir/$(basename "$target")"
  cursor=$home
  while [ "$cursor" != / ]; do
    prefix="../$prefix"
    cursor=$(dirname "$cursor")
  done
  printf '%s%s\n' "$prefix" "${target#/}"
}

create_expected_links() {
  local home=$1
  mkdir -p "$home/Library/Application Support/Code/User"
  ln -s "$repo_root/zsh/.zshrc" "$home/.zshrc"
  ln -s "$repo_root/git/.gitconfig" "$home/.gitconfig"
  ln -s "$repo_root/vscode/settings.json" "$home/Library/Application Support/Code/User/settings.json"
}

test_link_only_creates_all_manifest_links_and_is_idempotent() {
  local home
  home=$(new_home all-links)

  HOME="$home" DOTFILES_ROOT="$repo_root" "$repo_root/bootstrap" --link-only || return 1
  assert_path_points_to "$home/.zshrc" "$repo_root/zsh/.zshrc" || return 1
  assert_path_points_to "$home/.gitconfig" "$repo_root/git/.gitconfig" || return 1
  assert_path_points_to "$home/Library/Application Support/Code/User/settings.json" "$repo_root/vscode/settings.json" || return 1

  HOME="$home" DOTFILES_ROOT="$repo_root" "$repo_root/bootstrap" --link-only || return 1
  assert_path_points_to "$home/.zshrc" "$repo_root/zsh/.zshrc" || return 1
  assert_path_points_to "$home/.gitconfig" "$repo_root/git/.gitconfig" || return 1
  assert_path_points_to "$home/Library/Application Support/Code/User/settings.json" "$repo_root/vscode/settings.json" || return 1
}

test_conflicting_regular_file_is_preserved() {
  local home
  home=$(new_home regular-conflict)
  printf 'keep this file\n' >"$home/.zshrc"

  assert_command_fails env HOME="$home" DOTFILES_ROOT="$repo_root" "$repo_root/bootstrap" --link-only || return 1
  assert_file_contains "$home/.zshrc" 'keep this file' || return 1
  [ ! -L "$home/.zshrc" ] || fail "regular conflict was replaced with a symlink"
}

test_dangling_link_conflict_is_preserved() {
  local home original_target
  home=$(new_home dangling-conflict)
  original_target="$home/no-longer-exists"
  ln -s "$original_target" "$home/.gitconfig"

  assert_command_fails env HOME="$home" DOTFILES_ROOT="$repo_root" "$repo_root/bootstrap" --link-only || return 1
  assert_path_is_symlink "$home/.gitconfig" || return 1
  [ "$(readlink "$home/.gitconfig")" = "$original_target" ] || fail "dangling link was replaced"
}

test_backup_moves_conflicting_file_before_linking() {
  local home backup_root destination backup_file
  home=$(new_home backup-conflict)
  backup_root="$test_root/backup-conflict/backups"
  destination="$home/Library/Application Support/Code/User/settings.json"
  mkdir -p "$(dirname "$destination")"
  printf 'preserve settings\n' >"$destination"

  HOME="$home" DOTFILES_ROOT="$repo_root" DOTFILES_BACKUP_DIR="$backup_root" \
    "$repo_root/bootstrap" --link-only --backup || return 1
  backup_file="$backup_root/Library/Application Support/Code/User/settings.json"
  assert_file_contains "$backup_file" 'preserve settings' || return 1
  assert_path_points_to "$destination" "$repo_root/vscode/settings.json"
}

test_backup_preflight_rejects_existing_backup_target_before_any_move() {
  local home bin log backup_root backup_gitconfig
  home=$(new_home backup-preflight)
  bin=$(make_command_doubles backup-preflight)
  log="$test_root/backup-preflight/tool.log"
  backup_root="$test_root/backup-preflight/backups"
  backup_gitconfig="$backup_root/.gitconfig"
  : >"$log"
  printf 'keep zsh conflict\n' >"$home/.zshrc"
  printf 'keep git conflict\n' >"$home/.gitconfig"
  mkdir -p "$backup_root"
  printf 'existing backup must not be overwritten\n' >"$backup_gitconfig"

  assert_command_fails env HOME="$home" DOTFILES_ROOT="$repo_root" DOTFILES_BACKUP_DIR="$backup_root" \
    TEST_LOG="$log" BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" \
    "$repo_root/bootstrap" --link-only --backup || return 1
  assert_file_contains "$home/.zshrc" 'keep zsh conflict' || return 1
  [ ! -L "$home/.zshrc" ] || fail "first conflict was linked before complete backup preflight"
  assert_file_contains "$home/.gitconfig" 'keep git conflict' || return 1
  assert_file_contains "$backup_gitconfig" 'existing backup must not be overwritten' || return 1
  assert_path_absent "$backup_root/.zshrc" || return 1
  assert_path_absent "$home/Library/Application Support/Code/User/settings.json" || return 1
  [ ! -s "$log" ] || { fail "backup preflight failure invoked an external command"; return 1; }
}

test_dry_run_does_not_change_files_or_invoke_tools() {
  local home bin log output
  home=$(new_home dry-run)
  bin=$(make_command_doubles dry-run)
  log="$test_root/dry-run/tool.log"
  output="$test_root/dry-run/output.log"
  : >"$log"

  HOME="$home" DOTFILES_ROOT="$repo_root" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" \
    "$repo_root/bootstrap" --dry-run >"$output" || return 1
  assert_file_contains "$output" '.zshrc' || return 1
  [ ! -s "$log" ] || { fail "dry-run invoked an external command"; return 1; }
  assert_path_absent "$home/.zshrc" || return 1
  assert_path_absent "$home/.gitconfig" || return 1
  assert_path_absent "$home/Library"
}

test_bootstrap_invokes_brew_and_mise_through_overrides() {
  local home bin log
  home=$(new_home command-overrides)
  bin=$(make_command_doubles command-overrides)
  log="$test_root/command-overrides/tool.log"
  : >"$log"

  HOME="$home" DOTFILES_ROOT="$repo_root" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" "$repo_root/bootstrap" || return 1
  assert_file_contains "$log" "brew cwd=$repo_root argv=[bundle][install][--file][$repo_root/brew/Brewfile]" || return 1
  assert_file_contains "$log" "mise cwd=$repo_root/mise argv=[install]"
}

test_correct_relative_link_is_a_no_op() {
  local home target relative
  home=$(new_home relative-link)
  target="$repo_root/zsh/.zshrc"
  relative=$(relative_target_from_home "$home" "$target")
  ln -s "$relative" "$home/.zshrc"

  HOME="$home" DOTFILES_ROOT="$repo_root" "$repo_root/bootstrap" --link-only || return 1
  assert_path_points_to "$home/.zshrc" "$target" || return 1
  [ "$(readlink "$home/.zshrc")" = "$relative" ] || fail "correct relative link was rewritten"
}

test_correct_absolute_link_is_a_no_op() {
  local home target
  home=$(new_home absolute-link)
  target="$repo_root/zsh/.zshrc"
  ln -s "$target" "$home/.zshrc"

  HOME="$home" DOTFILES_ROOT="$repo_root" "$repo_root/bootstrap" --link-only || return 1
  assert_path_points_to "$home/.zshrc" "$target" || return 1
  [ "$(readlink "$home/.zshrc")" = "$target" ] || fail "correct absolute link was rewritten"
}

test_later_conflict_prevents_all_external_and_filesystem_mutations() {
  local home bin log destination
  home=$(new_home later-conflict)
  bin=$(make_command_doubles later-conflict)
  log="$test_root/later-conflict/tool.log"
  : >"$log"
  destination="$home/Library/Application Support/Code/User/settings.json"
  mkdir -p "$(dirname "$destination")"
  printf 'do not move\n' >"$destination"

  assert_command_fails env HOME="$home" DOTFILES_ROOT="$repo_root" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" "$repo_root/bootstrap" || return 1
  [ ! -s "$log" ] || { fail "preflight failure invoked an external command"; return 1; }
  assert_path_absent "$home/.zshrc" || return 1
  assert_path_absent "$home/.gitconfig" || return 1
  assert_file_contains "$destination" 'do not move'
}

test_invalid_manifest_prevents_all_external_and_filesystem_mutations() {
  local home bin log manifest
  home=$(new_home invalid-manifest)
  bin=$(make_command_doubles invalid-manifest)
  log="$test_root/invalid-manifest/tool.log"
  manifest="$test_root/invalid-manifest/links.tsv"
  : >"$log"
  printf 'zsh/.zshrc\t../outside\n' >"$manifest"

  assert_command_fails env HOME="$home" DOTFILES_ROOT="$repo_root" DOTFILES_MANIFEST="$manifest" \
    TEST_LOG="$log" BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" "$repo_root/bootstrap" || return 1
  [ ! -s "$log" ] || { fail "invalid manifest invoked an external command"; return 1; }
  assert_path_absent "$home/.zshrc" || return 1
  assert_path_absent "$home/outside"
}

test_manifest_source_escaping_root_prevents_all_link_backup_and_tool_side_effects() {
  local home bin log manifest backup_root
  home=$(new_home escaping-source-manifest)
  bin=$(make_command_doubles escaping-source-manifest)
  log="$test_root/escaping-source-manifest/tool.log"
  manifest="$test_root/escaping-source-manifest/links.tsv"
  backup_root="$test_root/escaping-source-manifest/backups"
  : >"$log"
  printf 'keep destination conflict\n' >"$home/.zshrc"
  printf '../outside\t.zshrc\n' >"$manifest"

  assert_command_fails env HOME="$home" DOTFILES_ROOT="$repo_root" DOTFILES_MANIFEST="$manifest" \
    DOTFILES_BACKUP_DIR="$backup_root" TEST_LOG="$log" BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" \
    "$repo_root/bootstrap" --link-only --backup || return 1
  assert_file_contains "$home/.zshrc" 'keep destination conflict' || return 1
  [ ! -L "$home/.zshrc" ] || fail "escaping manifest source changed destination"
  assert_path_absent "$backup_root/.zshrc" || return 1
  [ ! -s "$log" ] || { fail "escaping manifest source invoked an external command"; return 1; }
}

test_parent_child_destinations_fail_before_links_tools_or_source_mutation() {
  local home root manifest bin log status=0
  home=$(new_home parent-child-destinations)
  root=$(new_dotfiles_root parent-child-destinations)
  manifest="$root/manifests/links.tsv"
  bin=$(make_command_doubles parent-child-destinations)
  log="$test_root/parent-child-destinations/tool.log"
  : >"$log"
  mkdir -p "$root/sources/directory"
  printf 'child source\n' >"$root/sources/file"
  printf 'sources/directory\t.managed\nsources/file\t.managed/new-file\n' >"$manifest"

  if env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" "$repo_root/bootstrap"; then
    fail "parent and child destinations were accepted"
    status=1
  fi
  if [ -e "$home/.managed" ] || [ -L "$home/.managed" ]; then
    fail "parent destination was linked before topology preflight"
    status=1
  fi
  if [ -e "$home/.managed/new-file" ] || [ -L "$home/.managed/new-file" ]; then
    fail "child destination was created before topology preflight"
    status=1
  fi
  if [ -e "$root/sources/directory/new-file" ] || [ -L "$root/sources/directory/new-file" ]; then
    fail "child destination escaped through source-directory link"
    status=1
  fi
  if [ -s "$log" ]; then
    fail "parent-child topology failure invoked a tool"
    status=1
  fi
  return "$status"
}

test_normalized_destination_duplicates_fail_before_links_or_tools() {
  local home root manifest bin log status=0
  home=$(new_home normalized-destination-duplicates)
  root=$(new_dotfiles_root normalized-destination-duplicates)
  manifest="$root/manifests/links.tsv"
  bin=$(make_command_doubles normalized-destination-duplicates)
  log="$test_root/normalized-destination-duplicates/tool.log"
  : >"$log"
  printf 'first source\n' >"$root/sources/first"
  printf 'second source\n' >"$root/sources/second"
  printf 'sources/first\tfoo/bar\nsources/second\tfoo//bar\n' >"$manifest"

  if env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" "$repo_root/bootstrap"; then
    fail "normalized duplicate destinations were accepted"
    status=1
  fi
  if [ -e "$home/foo/bar" ] || [ -L "$home/foo/bar" ]; then
    fail "normalized duplicate created a partial link"
    status=1
  fi
  if [ -s "$log" ]; then
    fail "normalized duplicate invoked a tool"
    status=1
  fi
  return "$status"
}

test_regular_backup_root_fails_before_tools_or_mutation() {
  local home root manifest bin log backup_root status=0
  home=$(new_home regular-backup-root)
  root=$(new_dotfiles_root regular-backup-root)
  manifest="$root/manifests/links.tsv"
  bin=$(make_command_doubles regular-backup-root)
  log="$test_root/regular-backup-root/tool.log"
  backup_root="$test_root/regular-backup-root/not-a-directory"
  : >"$log"
  printf 'source remains unchanged\n' >"$root/sources/file"
  printf 'sources/file\t.zshrc\n' >"$manifest"
  printf 'backup root is a file\n' >"$backup_root"
  printf 'destination conflict remains\n' >"$home/.zshrc"

  if env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" \
    DOTFILES_BACKUP_DIR="$backup_root" TEST_LOG="$log" BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" \
    "$repo_root/bootstrap" --backup; then
    fail "regular backup root was accepted"
    status=1
  fi
  if ! grep -F -- 'source remains unchanged' "$root/sources/file" >/dev/null; then
    fail "source changed while backup root was invalid"
    status=1
  fi
  if [ -L "$home/.zshrc" ] || ! grep -F -- 'destination conflict remains' "$home/.zshrc" >/dev/null; then
    fail "destination changed while backup root was invalid"
    status=1
  fi
  if ! grep -F -- 'backup root is a file' "$backup_root" >/dev/null; then
    fail "regular backup root was changed"
    status=1
  fi
  if [ -s "$log" ]; then
    fail "regular backup root failure invoked a tool"
    status=1
  fi
  return "$status"
}

test_cyclic_destination_symlink_fails_promptly() {
  local home root manifest output attempt status=0
  home=$(new_home cyclic-destination)
  root=$(new_dotfiles_root cyclic-destination)
  manifest="$root/manifests/links.tsv"
  output="$test_root/cyclic-destination/output.log"
  printf 'source\n' >"$root/sources/file"
  printf 'sources/file\tloop/child\n' >"$manifest"
  ln -s loop "$home/loop"

  (
    env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" \
      "$repo_root/bootstrap" --link-only >"$output" 2>&1
  ) &
  test_child_pid=$!
  for attempt in 1 2 3; do
    if ! kill -0 "$test_child_pid" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  if kill -0 "$test_child_pid" 2>/dev/null; then
    kill "$test_child_pid" 2>/dev/null || true
    wait "$test_child_pid" 2>/dev/null || true
    test_child_pid=
    fail "cyclic destination symlink did not fail promptly"
    return 1
  fi
  if wait "$test_child_pid"; then
    fail "cyclic destination symlink was accepted"
    status=1
  fi
  test_child_pid=
  if [ -e "$home/loop/child" ] || [ -L "$home/loop/child" ]; then
    fail "cyclic destination created a child path"
    status=1
  fi
  return "$status"
}

test_relative_slash_mise_command_survives_mise_directory_change() {
  local home root manifest bin log runner_cwd relative_mise
  home=$(new_home relative-slash-mise)
  root=$(new_dotfiles_root relative-slash-mise)
  manifest="$root/manifests/links.tsv"
  bin=$(make_command_doubles relative-slash-mise)
  log="$test_root/relative-slash-mise/tool.log"
  runner_cwd=$(cd -P "$(pwd)" && pwd)
  relative_mise=$(relative_target_from_home "$runner_cwd" "$bin/mise")
  : >"$log"
  printf 'source\n' >"$root/sources/file"
  printf 'sources/file\t.config-file\n' >"$manifest"

  env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" TEST_LOG="$log" \
    MISE_CMD="$relative_mise" "$repo_root/bootstrap" --skip-brew || return 1
  assert_file_contains "$log" "mise cwd=$root/mise argv=[install]"
}

test_bare_mise_command_from_relative_path_survives_mise_directory_change() {
  local home root manifest bin log runner_cwd relative_bin
  home=$(new_home relative-path-mise)
  root=$(new_dotfiles_root relative-path-mise)
  manifest="$root/manifests/links.tsv"
  bin=$(make_command_doubles relative-path-mise)
  log="$test_root/relative-path-mise/tool.log"
  runner_cwd=$(cd -P "$(pwd)" && pwd)
  relative_bin=$(relative_target_from_home "$runner_cwd" "$bin")
  : >"$log"
  printf 'source\n' >"$root/sources/file"
  printf 'sources/file\t.config-file\n' >"$manifest"

  env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" TEST_LOG="$log" \
    PATH="$relative_bin:/usr/bin:/bin" MISE_CMD=mise "$repo_root/bootstrap" --skip-brew || return 1
  assert_file_contains "$log" "mise cwd=$root/mise argv=[install]"
}

test_dry_run_rejects_whitespace_command_overrides_without_side_effects() {
  local home root manifest bin log output status=0
  home=$(new_home dry-run-whitespace-overrides)
  root=$(new_dotfiles_root dry-run-whitespace-overrides)
  manifest="$root/manifests/links.tsv"
  bin=$(make_command_doubles dry-run-whitespace-overrides)
  log="$test_root/dry-run-whitespace-overrides/tool.log"
  output="$test_root/dry-run-whitespace-overrides/output.log"
  : >"$log"
  printf 'source\n' >"$root/sources/file"
  printf 'sources/file\t.config-file\n' >"$manifest"

  if env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" TEST_LOG="$log" \
    BREW_CMD='invalid brew' MISE_CMD="$bin/mise" "$repo_root/bootstrap" --dry-run >"$output" 2>&1; then
    fail "dry-run accepted whitespace-containing BREW_CMD"
    status=1
  fi
  if env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD='invalid mise' "$repo_root/bootstrap" --dry-run >>"$output" 2>&1; then
    fail "dry-run accepted whitespace-containing MISE_CMD"
    status=1
  fi
  if [ -e "$home/.config-file" ] || [ -L "$home/.config-file" ]; then
    fail "dry-run whitespace override created a destination"
    status=1
  fi
  if [ -s "$log" ]; then
    fail "dry-run whitespace override invoked a tool"
    status=1
  fi
  return "$status"
}

test_only_long_help_is_supported() {
  local status=0 argument
  for argument in -h -- positional; do
    if "$repo_root/bootstrap" "$argument" >/dev/null 2>&1; then
      fail "unsupported argument was accepted: $argument"
      status=1
    fi
  done
  if ! "$repo_root/bootstrap" --help >/dev/null 2>&1; then
    fail "--help did not succeed"
    status=1
  fi
  return "$status"
}

test_physical_alias_duplicate_destinations_fail_before_tools_or_links() {
  local home root manifest bin log status=0
  home=$(new_home physical-alias-duplicates)
  root=$(new_dotfiles_root physical-alias-duplicates)
  manifest="$root/manifests/links.tsv"
  bin=$(make_command_doubles physical-alias-duplicates)
  log="$test_root/physical-alias-duplicates/tool.log"
  : >"$log"
  mkdir -p "$home/real"
  ln -s "$home/real" "$home/alias"
  printf 'first source\n' >"$root/sources/first"
  printf 'second source\n' >"$root/sources/second"
  printf 'sources/first\talias/duplicate\nsources/second\treal/duplicate\n' >"$manifest"

  if env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" "$repo_root/bootstrap"; then
    fail "physical-alias duplicate destinations were accepted"
    status=1
  fi
  if [ -e "$home/alias/duplicate" ] || [ -L "$home/alias/duplicate" ]; then
    fail "alias duplicate destination was created before physical topology preflight"
    status=1
  fi
  if [ -e "$home/real/duplicate" ] || [ -L "$home/real/duplicate" ]; then
    fail "real duplicate destination was created before physical topology preflight"
    status=1
  fi
  if [ -s "$log" ]; then
    fail "physical-alias duplicate failure invoked a tool"
    status=1
  fi
  return "$status"
}

test_physical_alias_parent_child_destinations_fail_before_mutation() {
  local home root manifest bin log status=0
  home=$(new_home physical-alias-parent-child)
  root=$(new_dotfiles_root physical-alias-parent-child)
  manifest="$root/manifests/links.tsv"
  bin=$(make_command_doubles physical-alias-parent-child)
  log="$test_root/physical-alias-parent-child/tool.log"
  : >"$log"
  mkdir -p "$home/real" "$root/sources/directory"
  ln -s "$home/real" "$home/alias"
  printf 'child source\n' >"$root/sources/file"
  printf 'sources/directory\talias/parent\nsources/file\treal/parent/child\n' >"$manifest"

  if env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" "$repo_root/bootstrap"; then
    fail "physical-alias parent-child destinations were accepted"
    status=1
  fi
  if [ -e "$home/alias/parent" ] || [ -L "$home/alias/parent" ]; then
    fail "alias parent destination was linked before physical topology preflight"
    status=1
  fi
  if [ -e "$home/real/parent/child" ] || [ -L "$home/real/parent/child" ]; then
    fail "real child destination was created before physical topology preflight"
    status=1
  fi
  if [ -e "$root/sources/directory/child" ] || [ -L "$root/sources/directory/child" ]; then
    fail "physical-alias child write traversed the created source-directory link"
    status=1
  fi
  if [ -s "$log" ]; then
    fail "physical-alias parent-child failure invoked a tool"
    status=1
  fi
  return "$status"
}

test_nested_backup_symlink_escape_fails_before_links_or_moves() {
  local home root manifest bin log backup_root outside destination status=0
  home=$(new_home nested-backup-symlink)
  root=$(new_dotfiles_root nested-backup-symlink)
  manifest="$root/manifests/links.tsv"
  bin=$(make_command_doubles nested-backup-symlink)
  log="$test_root/nested-backup-symlink/tool.log"
  backup_root="$test_root/nested-backup-symlink/backups"
  outside="$test_root/nested-backup-symlink/outside"
  destination="$home/Library/Application Support/Code/User/settings.json"
  : >"$log"
  mkdir -p "$backup_root" "$outside" "$(dirname "$destination")"
  ln -s "$outside" "$backup_root/Library"
  printf 'source remains unchanged\n' >"$root/sources/file"
  printf 'sources/file\tLibrary/Application Support/Code/User/settings.json\n' >"$manifest"
  printf 'original destination remains regular\n' >"$destination"

  if env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" \
    DOTFILES_BACKUP_DIR="$backup_root" TEST_LOG="$log" BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" \
    "$repo_root/bootstrap" --link-only --backup; then
    fail "nested backup symlink escape was accepted"
    status=1
  fi
  if [ -e "$outside/Application Support/Code/User/settings.json" ] || \
    [ -L "$outside/Application Support/Code/User/settings.json" ]; then
    fail "backup move escaped through nested backup symlink"
    status=1
  fi
  if [ -L "$destination" ] || ! grep -F -- 'original destination remains regular' "$destination" >/dev/null; then
    fail "destination changed before nested backup symlink rejection"
    status=1
  fi
  if ! grep -F -- 'source remains unchanged' "$root/sources/file" >/dev/null; then
    fail "source changed during nested backup symlink handling"
    status=1
  fi
  if [ -s "$log" ]; then
    fail "nested backup symlink failure invoked a tool"
    status=1
  fi
  return "$status"
}

test_destination_resolving_to_source_fails_before_backup_or_link_mutation() {
  local home root manifest bin log backup_root backup_file source status=0
  home=$(new_home source-tree-collision)
  root="$home/dotfiles"
  manifest="$root/manifests/links.tsv"
  bin=$(make_command_doubles source-tree-collision)
  log="$test_root/source-tree-collision/tool.log"
  backup_root="$test_root/source-tree-collision/backups"
  backup_file="$backup_root/alias/file"
  source="$root/sources/managed/file"
  : >"$log"
  mkdir -p "$root/brew" "$root/manifests" "$root/mise" "$(dirname "$source")"
  printf 'source must remain regular\n' >"$source"
  ln -s "$root/sources/managed" "$home/alias"
  printf 'sources/managed/file\talias/file\n' >"$manifest"

  if env HOME="$home" DOTFILES_ROOT="$root" DOTFILES_MANIFEST="$manifest" \
    DOTFILES_BACKUP_DIR="$backup_root" TEST_LOG="$log" BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" \
    "$repo_root/bootstrap" --link-only --backup; then
    fail "destination resolving to source was accepted"
    status=1
  fi
  if [ -L "$source" ] || ! grep -F -- 'source must remain regular' "$source" >/dev/null; then
    fail "source was moved or replaced while destination resolved to source"
    status=1
  fi
  if [ -e "$backup_file" ] || [ -L "$backup_file" ]; then
    fail "source was backed up through a destination alias"
    status=1
  fi
  if [ -L "$home/alias/file" ]; then
    fail "link operation replaced the aliased source"
    status=1
  fi
  if [ -s "$log" ]; then
    fail "source-tree collision failure invoked a tool"
    status=1
  fi
  return "$status"
}

test_verify_detects_broken_link() {
  local home output
  home=$(new_home verify-broken-link)
  create_expected_links "$home"
  rm "$home/.gitconfig"
  ln -s "$home/missing-gitconfig" "$home/.gitconfig"
  output="$test_root/verify-broken-link/output.log"

  assert_command_fails sh -c 'HOME="$1" DOTFILES_ROOT="$2" "$2/verify" --skip-brew --skip-mise >"$3" 2>&1' \
    sh "$home" "$repo_root" "$output" || return 1
  assert_file_contains "$output" '.gitconfig'
}

test_verify_invokes_brew_and_mise_checks() {
  local home bin log
  home=$(new_home verify-command-overrides)
  create_expected_links "$home"
  bin=$(make_command_doubles verify-command-overrides)
  log="$test_root/verify-command-overrides/tool.log"
  : >"$log"

  HOME="$home" DOTFILES_ROOT="$repo_root" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" "$repo_root/verify" || return 1
  assert_file_contains "$log" "brew cwd=$repo_root argv=[bundle][check][--file][$repo_root/brew/Brewfile]" || return 1
  assert_file_contains "$log" "mise cwd=$repo_root/mise argv=[doctor]"
}

test_verify_aggregates_multiple_link_errors() {
  local home output
  home=$(new_home verify-aggregation)
  output="$test_root/verify-aggregation/output.log"

  assert_command_fails sh -c 'HOME="$1" DOTFILES_ROOT="$2" "$2/verify" --skip-brew --skip-mise >"$3" 2>&1' \
    sh "$home" "$repo_root" "$output" || return 1
  assert_file_contains "$output" '.zshrc' || return 1
  assert_file_contains "$output" '.gitconfig' || return 1
  assert_file_contains "$output" 'Library/Application Support/Code/User/settings.json'
}

test_verify_aggregates_link_and_package_check_errors() {
  local home bin log output
  home=$(new_home verify-full-aggregation)
  create_expected_links "$home"
  rm "$home/.gitconfig"
  ln -s "$home/missing-gitconfig" "$home/.gitconfig"
  bin=$(make_command_doubles verify-full-aggregation)
  log="$test_root/verify-full-aggregation/tool.log"
  output="$test_root/verify-full-aggregation/output.log"
  : >"$log"

  assert_command_fails sh -c 'HOME="$1" DOTFILES_ROOT="$2" TEST_LOG="$3" BREW_CMD="$4" MISE_CMD="$5" MOCK_BREW_EXIT=1 MOCK_MISE_EXIT=1 "$2/verify" >"$6" 2>&1' \
    sh "$home" "$repo_root" "$log" "$bin/brew" "$bin/mise" "$output" || return 1
  assert_file_contains "$output" '.gitconfig' || return 1
  assert_file_contains "$output" 'Brewfile check failed' || return 1
  assert_file_contains "$output" 'mise doctor failed' || return 1
  assert_file_contains "$log" "brew cwd=$repo_root argv=[bundle][check][--file][$repo_root/brew/Brewfile]" || return 1
  assert_file_contains "$log" "mise cwd=$repo_root/mise argv=[doctor]"
}

test_verify_skip_flags_avoid_package_command_calls() {
  local home bin log
  home=$(new_home verify-skip-package-checks)
  create_expected_links "$home"
  bin=$(make_command_doubles verify-skip-package-checks)
  log="$test_root/verify-skip-package-checks/tool.log"
  : >"$log"

  HOME="$home" DOTFILES_ROOT="$repo_root" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" \
    "$repo_root/verify" --skip-brew --skip-mise || return 1
  [ ! -s "$log" ] || fail "verify skip flags invoked a package command"
}

test_verify_rejects_destination_escaping_home_through_symlink_parent() {
  local home outside manifest output
  home=$(new_home verify-destination-escape)
  outside="$test_root/verify-destination-escape/outside"
  manifest="$test_root/verify-destination-escape/links.tsv"
  output="$test_root/verify-destination-escape/output.log"
  mkdir -p "$outside"
  ln -s "$outside" "$home/linked-parent"
  ln -s "$repo_root/zsh/.zshrc" "$outside/file"
  printf 'zsh/.zshrc\tlinked-parent/file\n' >"$manifest"

  assert_command_fails sh -c 'HOME="$1" DOTFILES_ROOT="$2" DOTFILES_MANIFEST="$3" "$2/verify" --skip-brew --skip-mise >"$4" 2>&1' \
    sh "$home" "$repo_root" "$manifest" "$output" || return 1
  assert_file_contains "$output" 'escapes HOME through a symlink parent' || return 1
  assert_path_points_to "$outside/file" "$repo_root/zsh/.zshrc"
}

test_verify_reports_invalid_dotfiles_root_with_nonzero_problem_count() {
  local home invalid_root output
  home=$(new_home verify-invalid-root)
  invalid_root="$test_root/verify-invalid-root/not-a-directory"
  output="$test_root/verify-invalid-root/output.log"

  assert_command_fails sh -c 'HOME="$1" DOTFILES_ROOT="$2" "$3/verify" --skip-brew --skip-mise >"$4" 2>&1' \
    sh "$home" "$invalid_root" "$repo_root" "$output" || return 1
  assert_file_contains "$output" 'DOTFILES_ROOT is not a directory' || return 1
  assert_file_contains "$output" 'Verification failed: 1 problem(s) found.'
}

test_verify_only_long_help_is_supported() {
  local argument stdout_path stderr_path status=0

  stdout_path="$test_root/verify-cli-help.stdout"
  stderr_path="$test_root/verify-cli-help.stderr"
  assert_command_exit_code 0 "$stdout_path" "$stderr_path" "$repo_root/verify" --help || status=1
  assert_file_contains "$stdout_path" 'Usage: ./verify [--skip-brew] [--skip-mise] [--help]' || status=1
  assert_file_empty "$stderr_path" || status=1

  for argument in -h -- positional --unknown; do
    stdout_path="$test_root/verify-cli-${argument#--}.stdout"
    stderr_path="$test_root/verify-cli-${argument#--}.stderr"
    assert_command_exit_code 2 "$stdout_path" "$stderr_path" "$repo_root/verify" "$argument" || status=1
    assert_file_empty "$stdout_path" || status=1
    assert_file_contains "$stderr_path" "Error: unknown option: $argument" || status=1
    assert_file_contains "$stderr_path" 'Usage: ./verify [--skip-brew] [--skip-mise] [--help]' || status=1
  done
  return "$status"
}

test_verify_does_not_invoke_destructive_commands_or_change_home() {
  local home bin log original_zsh original_git original_settings line_count status=0
  home=$(new_home verify-no-side-effects)
  create_expected_links "$home"
  printf 'preserve this unmanaged file\n' >"$home/unmanaged.txt"
  bin=$(make_command_doubles verify-no-side-effects)
  log="$test_root/verify-no-side-effects/tool.log"
  : >"$log"
  original_zsh=$(readlink "$home/.zshrc")
  original_git=$(readlink "$home/.gitconfig")
  original_settings=$(readlink "$home/Library/Application Support/Code/User/settings.json")

  for command_name in ln mv mkdir; do
    cat >"$bin/$command_name" <<'EOF'
#!/bin/bash
set -eu
: "${TEST_LOG:?TEST_LOG must be set}"
printf 'destructive command=%s\n' "$(basename "$0")" >>"$TEST_LOG"
exit 99
EOF
    chmod +x "$bin/$command_name"
  done

  PATH="$bin:/usr/bin:/bin" HOME="$home" DOTFILES_ROOT="$repo_root" TEST_LOG="$log" \
    BREW_CMD="$bin/brew" MISE_CMD="$bin/mise" "$repo_root/verify" || return 1
  if grep -F -- 'destructive command=' "$log" >/dev/null; then
    fail "verify invoked a destructive command"
    status=1
  fi
  assert_file_contains "$log" "brew cwd=$repo_root argv=[bundle][check][--file][$repo_root/brew/Brewfile]" || status=1
  assert_file_contains "$log" "mise cwd=$repo_root/mise argv=[doctor]" || status=1
  line_count=$(wc -l <"$log")
  [ "$line_count" -eq 2 ] || { fail "verify logged unexpected command calls"; status=1; }
  [ "$(readlink "$home/.zshrc")" = "$original_zsh" ] || { fail "verify changed .zshrc target"; status=1; }
  [ "$(readlink "$home/.gitconfig")" = "$original_git" ] || { fail "verify changed .gitconfig target"; status=1; }
  [ "$(readlink "$home/Library/Application Support/Code/User/settings.json")" = "$original_settings" ] || {
    fail "verify changed settings target"
    status=1
  }
  assert_file_contains "$home/unmanaged.txt" 'preserve this unmanaged file' || status=1
  return "$status"
}

test_verify_rejects_physical_alias_duplicate_destinations() {
  local home manifest output
  home=$(new_home verify-physical-alias-duplicates)
  manifest="$test_root/verify-physical-alias-duplicates/links.tsv"
  output="$test_root/verify-physical-alias-duplicates/output.log"
  mkdir -p "$home/real"
  ln -s "$home/real" "$home/alias"
  ln -s "$repo_root/zsh/.zshrc" "$home/alias/managed"
  printf 'zsh/.zshrc\talias/managed\nzsh/.zshrc\treal/managed\n' >"$manifest"

  assert_command_fails sh -c 'HOME="$1" DOTFILES_ROOT="$2" DOTFILES_MANIFEST="$3" "$2/verify" --skip-brew --skip-mise >"$4" 2>&1' \
    sh "$home" "$repo_root" "$manifest" "$output" || return 1
  assert_file_contains "$output" 'manifest destinations resolve to the same or nested physical paths' || return 1
  assert_path_points_to "$home/alias/managed" "$repo_root/zsh/.zshrc"
}

test_verify_rejects_physical_alias_parent_child_destinations() {
  local home manifest output
  home=$(new_home verify-physical-alias-parent-child)
  manifest="$test_root/verify-physical-alias-parent-child/links.tsv"
  output="$test_root/verify-physical-alias-parent-child/output.log"
  mkdir -p "$home/real"
  ln -s "$home/real" "$home/alias"
  printf 'zsh/.zshrc\talias/parent\ngit/.gitconfig\treal/parent/child\n' >"$manifest"

  assert_command_fails sh -c 'HOME="$1" DOTFILES_ROOT="$2" DOTFILES_MANIFEST="$3" "$2/verify" --skip-brew --skip-mise >"$4" 2>&1' \
    sh "$home" "$repo_root" "$manifest" "$output" || return 1
  assert_file_contains "$output" 'manifest destinations resolve to the same or nested physical paths'
}

test_verify_rejects_source_symlink_escaping_dotfiles_root_and_aggregates_links() {
  local home root manifest outside output
  home=$(new_home verify-source-escape)
  root=$(new_dotfiles_root verify-source-escape)
  manifest="$root/manifests/links.tsv"
  outside="$test_root/verify-source-escape/outside"
  output="$test_root/verify-source-escape/output.log"
  mkdir -p "$outside"
  git init -q "$root"
  printf 'outside source\n' >"$outside/escape"
  printf 'valid source\n' >"$root/sources/valid"
  ln -s "$outside/escape" "$root/sources/escape"
  printf 'sources/escape\t.escaped\nsources/valid\t.missing\n' >"$manifest"

  assert_command_fails sh -c 'HOME="$1" DOTFILES_ROOT="$2" DOTFILES_MANIFEST="$3" "$4/verify" --skip-brew --skip-mise >"$5" 2>&1' \
    sh "$home" "$root" "$manifest" "$repo_root" "$output" || return 1
  assert_file_contains "$output" 'manifest source escapes DOTFILES_ROOT: sources/escape' || return 1
  assert_file_contains "$output" '.missing'
}

run_test test_readme_documents_bootstrap_restore_workflow
run_test test_link_only_creates_all_manifest_links_and_is_idempotent
run_test test_conflicting_regular_file_is_preserved
run_test test_dangling_link_conflict_is_preserved
run_test test_backup_moves_conflicting_file_before_linking
run_test test_backup_preflight_rejects_existing_backup_target_before_any_move
run_test test_dry_run_does_not_change_files_or_invoke_tools
run_test test_bootstrap_invokes_brew_and_mise_through_overrides
run_test test_correct_relative_link_is_a_no_op
run_test test_correct_absolute_link_is_a_no_op
run_test test_later_conflict_prevents_all_external_and_filesystem_mutations
run_test test_invalid_manifest_prevents_all_external_and_filesystem_mutations
run_test test_manifest_source_escaping_root_prevents_all_link_backup_and_tool_side_effects
run_test test_parent_child_destinations_fail_before_links_tools_or_source_mutation
run_test test_normalized_destination_duplicates_fail_before_links_or_tools
run_test test_regular_backup_root_fails_before_tools_or_mutation
run_test test_cyclic_destination_symlink_fails_promptly
run_test test_relative_slash_mise_command_survives_mise_directory_change
run_test test_bare_mise_command_from_relative_path_survives_mise_directory_change
run_test test_dry_run_rejects_whitespace_command_overrides_without_side_effects
run_test test_only_long_help_is_supported
run_test test_physical_alias_duplicate_destinations_fail_before_tools_or_links
run_test test_physical_alias_parent_child_destinations_fail_before_mutation
run_test test_nested_backup_symlink_escape_fails_before_links_or_moves
run_test test_destination_resolving_to_source_fails_before_backup_or_link_mutation
run_test test_verify_detects_broken_link
run_test test_verify_invokes_brew_and_mise_checks
run_test test_verify_aggregates_multiple_link_errors
run_test test_verify_aggregates_link_and_package_check_errors
run_test test_verify_skip_flags_avoid_package_command_calls
run_test test_verify_rejects_destination_escaping_home_through_symlink_parent
run_test test_verify_reports_invalid_dotfiles_root_with_nonzero_problem_count
run_test test_verify_only_long_help_is_supported
run_test test_verify_does_not_invoke_destructive_commands_or_change_home
run_test test_verify_rejects_physical_alias_duplicate_destinations
run_test test_verify_rejects_physical_alias_parent_child_destinations
run_test test_verify_rejects_source_symlink_escaping_dotfiles_root_and_aggregates_links

echo "Passed: $passed"
echo "Failed: $failed"
[ "$failed" -eq 0 ]
