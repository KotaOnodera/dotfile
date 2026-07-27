#!/bin/bash

# Shared helpers for the bootstrap and verify entrypoints.  They deliberately
# avoid Bash 4 features so they also run with the macOS-provided Bash 3.2.

dotfiles_error() {
  printf 'Error: %s\n' "$*" >&2
  return 1
}

dotfiles_root() {
  local root

  if [ -n "${DOTFILES_ROOT:-}" ]; then
    root=$DOTFILES_ROOT
  else
    root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P) || return 1
  fi

  [ -d "$root" ] || { dotfiles_error "DOTFILES_ROOT is not a directory: $root"; return 1; }
  (cd "$root" && pwd -P)
}

# Package commands intentionally use the caller-declared root spelling. The
# canonical dotfiles_root remains the authority for containment checks, while
# this preserves the documented "$DOTFILES_ROOT/mise" working directory (for
# example, /tmp rather than macOS's physical /private/tmp alias).
dotfiles_command_root() {
  if [ -n "${DOTFILES_ROOT:-}" ]; then
    printf '%s\n' "$DOTFILES_ROOT"
  else
    dotfiles_root
  fi
}

manifest_path() {
  if [ -n "${DOTFILES_MANIFEST:-}" ]; then
    printf '%s\n' "$DOTFILES_MANIFEST"
  else
    printf '%s/manifests/links.tsv\n' "$(dotfiles_root)"
  fi
}

# Resolve an existing file or directory without relying on GNU readlink -f,
# which is unavailable in the macOS base system.
resolve_existing_path() {
  local path=$1 link parent link_count=0 link_limit=64

  while [ -L "$path" ]; do
    link_count=$((link_count + 1))
    [ "$link_count" -le "$link_limit" ] || return 1
    link=$(readlink "$path") || return 1
    case "$link" in
      /*) path=$link ;;
      *) path=$(dirname "$path")/$link ;;
    esac
  done

  if [ "$path" = / ]; then
    printf '/\n'
    return 0
  fi

  parent=$(cd -P "$(dirname "$path")" 2>/dev/null && pwd) || return 1
  printf '%s/%s\n' "$parent" "$(basename "$path")"
}

# Normalize a manifest-relative path without touching the filesystem. Parent
# components are rejected separately before this is called, so normalization
# only needs to remove repeated separators and current-directory components.
normalize_relative_path() {
  local remainder=$1 component normalized= final_component=0

  while [ "$final_component" -eq 0 ]; do
    case "$remainder" in
      */*)
        component=${remainder%%/*}
        remainder=${remainder#*/}
        ;;
      *)
        component=$remainder
        remainder=
        final_component=1
        ;;
    esac

    case "$component" in
      ''|.) ;;
      *)
        if [ -n "$normalized" ]; then
          normalized=$normalized/$component
        else
          normalized=$component
        fi
        ;;
    esac
  done

  [ -n "$normalized" ] || return 1
  printf '%s\n' "$normalized"
}

# Produce a lexical absolute path for structural comparisons. This does not
# inspect the filesystem; resolve_path_for_creation below resolves the deepest
# existing ancestor afterward so symlinked prefixes are also canonicalized.
normalize_absolute_path() {
  local remainder=$1 component normalized= final_component=0

  case "$remainder" in /*) ;; *) remainder=$PWD/$remainder ;; esac
  while [ "$final_component" -eq 0 ]; do
    case "$remainder" in
      */*)
        component=${remainder%%/*}
        remainder=${remainder#*/}
        ;;
      *)
        component=$remainder
        remainder=
        final_component=1
        ;;
    esac

    case "$component" in
      ''|.) ;;
      ..)
        case "$normalized" in
          */*) normalized=${normalized%/*} ;;
          *) normalized= ;;
        esac
        ;;
      *)
        if [ -n "$normalized" ]; then
          normalized=$normalized/$component
        else
          normalized=$component
        fi
        ;;
    esac
  done

  if [ -n "$normalized" ]; then
    printf '/%s\n' "$normalized"
  else
    printf '/\n'
  fi
}

path_has_parent_component() {
  case "/$1/" in
    */../*) return 0 ;;
    *) return 1 ;;
  esac
}

path_is_beneath() {
  local path=$1 root=$2
  [ "$path" = "$root" ] || case "$path" in "$root"/*) return 0 ;; *) return 1 ;; esac
}

paths_have_parent_child_relationship() {
  local first=$1 second=$2

  case "$first" in "$second"/*) return 0 ;; esac
  case "$second" in "$first"/*) return 0 ;; esac
  return 1
}

paths_have_structural_collision() {
  local first=$1 second=$2

  [ "$first" = "$second" ] || paths_have_parent_child_relationship "$first" "$second"
}

is_expected_link() {
  local destination=$1 source=$2 resolved_destination resolved_source

  [ -L "$destination" ] || return 1
  resolved_destination=$(resolve_existing_path "$destination") || return 1
  resolved_source=$(resolve_existing_path "$source") || return 1

  # Bash 3.2's -ef is the authoritative same-file check (including hard
  # links).  Comparing the fully resolved names also keeps correct relative
  # symlinks idempotent on filesystems where -ef is unreliable for them.
  [ "$destination" -ef "$source" ] || [ "$resolved_destination" = "$resolved_source" ]
}

destination_parent_is_safe() {
  local destination=$1 home=$2 ancestor resolved_ancestor

  ancestor=$(dirname "$destination")
  while [ ! -e "$ancestor" ] && [ ! -L "$ancestor" ]; do
    [ "$ancestor" != / ] || { dotfiles_error "cannot find an existing parent for $destination"; return 1; }
    ancestor=$(dirname "$ancestor")
  done

  [ -d "$ancestor" ] || { dotfiles_error "destination parent is not a directory: $ancestor"; return 1; }
  resolved_ancestor=$(resolve_existing_path "$ancestor") || {
    dotfiles_error "cannot resolve destination parent: $ancestor"
    return 1
  }
  path_is_beneath "$resolved_ancestor" "$home" || {
    dotfiles_error "destination parent escapes HOME through a symlink: $destination"
    return 1
  }
}

# Confirm that mkdir -p can reach a path without crossing an existing
# non-directory or dangling/cyclic symlink. This is a pure preflight check.
deepest_existing_ancestor_is_directory() {
  local path=$1 label=$2 ancestor parent

  ancestor=$path
  while [ ! -e "$ancestor" ] && [ ! -L "$ancestor" ]; do
    parent=$(dirname "$ancestor")
    [ "$parent" != "$ancestor" ] || {
      dotfiles_error "cannot find an existing directory ancestor for $label: $path"
      return 1
    }
    ancestor=$parent
  done

  [ -d "$ancestor" ] || {
    dotfiles_error "$label has a non-directory existing ancestor: $ancestor"
    return 1
  }
  resolve_existing_path "$ancestor" >/dev/null || {
    dotfiles_error "$label has an unresolvable existing ancestor: $ancestor"
    return 1
  }
}

# Resolve the existing prefix of a not-yet-created path and retain its missing
# suffix. The result is stable and suitable for topology comparisons before
# mkdir or mv is allowed to run.
resolve_path_for_creation() {
  local path ancestor parent component suffix= resolved_ancestor

  path=$(normalize_absolute_path "$1") || return 1
  ancestor=$path
  while [ ! -e "$ancestor" ] && [ ! -L "$ancestor" ]; do
    component=$(basename "$ancestor")
    if [ -n "$suffix" ]; then
      suffix=$component/$suffix
    else
      suffix=$component
    fi
    parent=$(dirname "$ancestor")
    [ "$parent" != "$ancestor" ] || return 1
    ancestor=$parent
  done

  [ -d "$ancestor" ] || return 1
  resolved_ancestor=$(resolve_existing_path "$ancestor") || return 1
  if [ -z "$suffix" ]; then
    printf '%s\n' "$resolved_ancestor"
  elif [ "$resolved_ancestor" = / ]; then
    printf '/%s\n' "$suffix"
  else
    printf '%s/%s\n' "$resolved_ancestor" "$suffix"
  fi
}

# Resolve the parent of a leaf that will be created or replaced, then append
# the leaf name without following an existing leaf symlink. This models the
# physical identity of mkdir/ln/mv destinations through existing parent
# aliases while preserving the destination entry itself as the replacement
# point.
resolve_planned_creation_path() {
  local path parent leaf resolved_parent

  path=$(normalize_absolute_path "$1") || return 1
  parent=$(dirname "$path")
  leaf=$(basename "$path")
  resolved_parent=$(resolve_path_for_creation "$parent") || return 1
  if [ "$resolved_parent" = / ]; then
    printf '/%s\n' "$leaf"
  else
    printf '%s/%s\n' "$resolved_parent" "$leaf"
  fi
}

backup_root_for_run() {
  if [ -n "${DOTFILES_BACKUP_DIR:-}" ]; then
    printf '%s\n' "$DOTFILES_BACKUP_DIR"
  else
    printf '%s/.dotfiles-backups/%s-%s\n' "$HOME" "$(date +%Y%m%d%H%M%S)" "$$"
  fi
}

# Validate every manifest entry and every possible backup target before any
# package manager, mkdir, mv, or ln side effect.  The resulting globals are
# intentionally retained for create_declared_links in this shell process.
preflight_declared_links() {
  local backup_enabled=${1:-0}
  local root manifest home line source destination raw_destination remainder tab resolved_source
  local destination_path planned_destination backup_root backup_target planned_backup_target
  local seen seen_destinations seen_path seen_destination_paths planned_backup planned_backup_targets
  local entry_backup preflight_plan

  root=$(dotfiles_root) || return 1
  manifest=$(manifest_path) || return 1
  [ -f "$manifest" ] || { dotfiles_error "manifest does not exist: $manifest"; return 1; }
  [ -d "${HOME:-}" ] || { dotfiles_error "HOME is not a directory: ${HOME:-}"; return 1; }
  home=$(cd "$HOME" && pwd -P) || return 1
  tab=$(printf '\t')
  seen_destinations=
  seen_destination_paths=
  planned_backup_targets=
  preflight_plan=
  backup_root=
  if [ "$backup_enabled" -eq 1 ]; then
    backup_root=$(backup_root_for_run)
    deepest_existing_ancestor_is_directory "$backup_root" "backup root" || return 1
    backup_root=$(resolve_path_for_creation "$backup_root") || {
      dotfiles_error "backup root cannot be resolved safely"
      return 1
    }
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac

    case "$line" in
      *"$tab"*) ;;
      *) dotfiles_error "manifest entry must have exactly two tab-separated columns: $line"; return 1 ;;
    esac
    source=${line%%"$tab"*}
    remainder=${line#*"$tab"}
    case "$remainder" in
      *"$tab"*) dotfiles_error "manifest entry must have exactly two tab-separated columns: $line"; return 1 ;;
    esac
    raw_destination=$remainder

    [ -n "$source" ] && [ -n "$raw_destination" ] || {
      dotfiles_error "manifest source and destination must be nonempty: $line"
      return 1
    }
    case "$source" in /*) dotfiles_error "manifest source must be relative: $source"; return 1 ;; esac
    case "$raw_destination" in /*) dotfiles_error "manifest destination must be relative: $raw_destination"; return 1 ;; esac
    if path_has_parent_component "$source" || path_has_parent_component "$raw_destination"; then
      dotfiles_error "manifest paths may not contain .. components: $line"
      return 1
    fi
    destination=$(normalize_relative_path "$raw_destination") || {
      dotfiles_error "manifest destination is empty after normalization: $raw_destination"
      return 1
    }

    while IFS= read -r seen || [ -n "$seen" ]; do
      if [ "$seen" = "$destination" ]; then
        dotfiles_error "manifest destination is duplicated: $destination"
        return 1
      fi
      if paths_have_parent_child_relationship "$seen" "$destination"; then
        dotfiles_error "manifest destinations may not be parents or children of each other: $seen and $destination"
        return 1
      fi
    done <<EOF
$seen_destinations
EOF
    if [ -n "$seen_destinations" ]; then
      seen_destinations=$seen_destinations$'\n'$destination
    else
      seen_destinations=$destination
    fi

    # resolve_existing_path canonicalizes paths, but its final component may
    # be absent.  Check existence first so missing files and dangling source
    # symlinks can never be accepted as manifest entries.
    [ -e "$root/$source" ] || {
      if [ -L "$root/$source" ]; then
        dotfiles_error "manifest source is a dangling symlink: $source"
      else
        dotfiles_error "manifest source does not exist: $source"
      fi
      return 1
    }
    resolved_source=$(resolve_existing_path "$root/$source") || {
      dotfiles_error "manifest source does not exist: $source"
      return 1
    }
    path_is_beneath "$resolved_source" "$root" || {
      dotfiles_error "manifest source escapes DOTFILES_ROOT: $source"
      return 1
    }

    destination_path=$home/$destination
    planned_destination=$(resolve_planned_creation_path "$destination_path") || {
      dotfiles_error "destination cannot be resolved safely: $destination_path"
      return 1
    }
    path_is_beneath "$planned_destination" "$home" || {
      dotfiles_error "destination escapes HOME through a symlink parent: $destination_path"
      return 1
    }
    ! paths_have_structural_collision "$planned_destination" "$root" || {
      dotfiles_error "destination collides with managed DOTFILES_ROOT: $planned_destination"
      return 1
    }

    while IFS= read -r seen_path || [ -n "$seen_path" ]; do
      [ -z "$seen_path" ] || \
        ! paths_have_structural_collision "$planned_destination" "$seen_path" || {
          dotfiles_error "manifest destinations resolve to the same or nested physical paths: $planned_destination and $seen_path"
          return 1
        }
    done <<EOF
$seen_destination_paths
EOF

    if [ "$backup_enabled" -eq 1 ]; then
      while IFS= read -r planned_backup || [ -n "$planned_backup" ]; do
        [ -z "$planned_backup" ] || \
          ! paths_have_structural_collision "$planned_destination" "$planned_backup" || {
            dotfiles_error "destination collides structurally with a backup target: $planned_destination and $planned_backup"
            return 1
          }
      done <<EOF
$planned_backup_targets
EOF
    fi

    if [ -n "$seen_destination_paths" ]; then
      seen_destination_paths=$seen_destination_paths$'\n'$planned_destination
    else
      seen_destination_paths=$planned_destination
    fi

    entry_backup=-
    if [ -e "$planned_destination" ] || [ -L "$planned_destination" ]; then
      if ! is_expected_link "$planned_destination" "$resolved_source"; then
        if [ "$backup_enabled" -ne 1 ]; then
          dotfiles_error "destination conflicts with managed link: $planned_destination (use --backup to preserve it)"
          return 1
        fi
        backup_target=$backup_root/$destination
        planned_backup_target=$(resolve_planned_creation_path "$backup_target") || {
          dotfiles_error "backup target cannot be resolved safely: $backup_target"
          return 1
        }
        [ "$planned_backup_target" != "$backup_root" ] && \
          path_is_beneath "$planned_backup_target" "$backup_root" || {
            dotfiles_error "backup target escapes canonical backup root: $backup_target"
            return 1
          }
        ! paths_have_structural_collision "$planned_backup_target" "$root" || {
          dotfiles_error "backup target collides with managed DOTFILES_ROOT: $planned_backup_target"
          return 1
        }
        if [ -e "$planned_backup_target" ] || [ -L "$planned_backup_target" ]; then
          dotfiles_error "backup target already exists: $planned_backup_target"
          return 1
        fi
        deepest_existing_ancestor_is_directory "$(dirname "$planned_backup_target")" \
          "backup target" || return 1

        while IFS= read -r seen_path || [ -n "$seen_path" ]; do
          [ -z "$seen_path" ] || \
            ! paths_have_structural_collision "$planned_backup_target" "$seen_path" || {
              dotfiles_error "backup target collides structurally with a destination: $planned_backup_target and $seen_path"
              return 1
            }
        done <<EOF
$seen_destination_paths
EOF
        while IFS= read -r planned_backup || [ -n "$planned_backup" ]; do
          [ -z "$planned_backup" ] || \
            ! paths_have_structural_collision "$planned_backup_target" "$planned_backup" || {
              dotfiles_error "backup targets collide structurally: $planned_backup_target and $planned_backup"
              return 1
            }
        done <<EOF
$planned_backup_targets
EOF
        if [ -n "$planned_backup_targets" ]; then
          planned_backup_targets=$planned_backup_targets$'\n'$planned_backup_target
        else
          planned_backup_targets=$planned_backup_target
        fi
        entry_backup=$planned_backup_target
      fi
    fi

    if [ -n "$preflight_plan" ]; then
      preflight_plan=$preflight_plan$'\n'$resolved_source$tab$planned_destination$tab$entry_backup
    else
      preflight_plan=$resolved_source$tab$planned_destination$tab$entry_backup
    fi
  done <"$manifest"

  DOTFILES_PREFLIGHT_DONE=1
  DOTFILES_PREFLIGHT_BACKUP_ENABLED=$backup_enabled
  DOTFILES_PREFLIGHT_BACKUP_ROOT=$backup_root
  DOTFILES_PREFLIGHT_ROOT=$root
  DOTFILES_PREFLIGHT_MANIFEST=$manifest
  DOTFILES_PREFLIGHT_HOME=$home
  DOTFILES_PREFLIGHT_PLAN=$preflight_plan
}

backup_destination() {
  local destination=$1 backup_target=$2

  [ ! -e "$backup_target" ] && [ ! -L "$backup_target" ] || {
    dotfiles_error "backup target already exists: $backup_target"
    return 1
  }
  mkdir -p "$(dirname "$backup_target")"
  printf 'mv %s %s\n' "$destination" "$backup_target"
  mv "$destination" "$backup_target"
}

create_declared_links() {
  local backup_enabled=${1:-0} dry_run=${2:-0}
  local root home line resolved_source destination_path backup_target remainder tab
  local current_destination current_backup parent

  if [ "${DOTFILES_PREFLIGHT_DONE:-0}" -ne 1 ] || \
     [ "${DOTFILES_PREFLIGHT_BACKUP_ENABLED:-}" != "$backup_enabled" ]; then
    preflight_declared_links "$backup_enabled" || return 1
  fi
  root=$DOTFILES_PREFLIGHT_ROOT
  home=$DOTFILES_PREFLIGHT_HOME
  tab=$(printf '\t')

  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    resolved_source=${line%%"$tab"*}
    remainder=${line#*"$tab"}
    destination_path=${remainder%%"$tab"*}
    backup_target=${remainder#*"$tab"}

    current_destination=$(resolve_planned_creation_path "$destination_path") || {
      dotfiles_error "destination identity changed after preflight: $destination_path"
      return 1
    }
    [ "$current_destination" = "$destination_path" ] && \
      path_is_beneath "$current_destination" "$home" || {
        dotfiles_error "destination identity is no longer safe: $destination_path"
        return 1
      }
    ! paths_have_structural_collision "$current_destination" "$root" || {
      dotfiles_error "destination now collides with managed DOTFILES_ROOT: $current_destination"
      return 1
    }

    if is_expected_link "$destination_path" "$resolved_source"; then
      continue
    fi
    if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
      if [ "$backup_enabled" -eq 1 ]; then
        [ "$backup_target" != - ] || {
          dotfiles_error "backup target is missing from the validated plan: $destination_path"
          return 1
        }
        current_backup=$(resolve_planned_creation_path "$backup_target") || {
          dotfiles_error "backup target identity changed after preflight: $backup_target"
          return 1
        }
        [ "$current_backup" = "$backup_target" ] || {
          dotfiles_error "backup target identity is no longer safe: $backup_target"
          return 1
        }
        ! paths_have_structural_collision "$current_backup" "$root" || {
          dotfiles_error "backup target now collides with managed DOTFILES_ROOT: $current_backup"
          return 1
        }
        if [ "$dry_run" -eq 1 ]; then
          printf 'mv %s %s\n' "$destination_path" "$backup_target"
        else
          backup_destination "$destination_path" "$backup_target" || return 1
        fi
      else
        dotfiles_error "destination conflicts with managed link: $destination_path"
        return 1
      fi
    fi

    parent=$(dirname "$destination_path")
    if [ "$dry_run" -eq 1 ]; then
      printf 'mkdir -p %s\n' "$parent"
      printf 'ln -s %s %s\n' "$resolved_source" "$destination_path"
    else
      mkdir -p "$parent"
      printf 'ln -s %s %s\n' "$resolved_source" "$destination_path"
      ln -s "$resolved_source" "$destination_path"
    fi
  done <<EOF
$DOTFILES_PREFLIGHT_PLAN
EOF
}

validate_command_override() {
  local command_name=$1 label=$2

  [ -n "$command_name" ] || {
    dotfiles_error "$label command override must not be empty"
    return 1
  }
  case "$command_name" in
    *[[:space:]]*) dotfiles_error "$label command override must be one command name or path"; return 1 ;;
  esac
}

command_path_or_error() {
  local command_name=$1 label=$2 candidate resolved_command

  validate_command_override "$command_name" "$label" || return 1
  case "$command_name" in
    */*) candidate=$command_name ;;
    *)
      candidate=$(command -v "$command_name" 2>/dev/null) || {
        dotfiles_error "$label is required; install it before running this command"
        return 1
      }
      case "$candidate" in
        */*) ;;
        *) dotfiles_error "$label command is not an executable file: $command_name"; return 1 ;;
      esac
      ;;
  esac

  [ -f "$candidate" ] && [ -x "$candidate" ] || {
    dotfiles_error "$label command was not found or is not executable: $command_name"
    return 1
  }
  resolved_command=$(resolve_existing_path "$candidate") || {
    dotfiles_error "$label command could not be resolved: $command_name"
    return 1
  }
  [ -f "$resolved_command" ] && [ -x "$resolved_command" ] || {
    dotfiles_error "$label command does not resolve to an executable file: $command_name"
    return 1
  }
  printf '%s\n' "$resolved_command"
}

run_brew_bundle_install() {
  local root command_name command_path
  root=$(dotfiles_command_root) || return 1
  if [ "$#" -gt 0 ]; then
    command_path=$1
  else
    command_name=${BREW_CMD-brew}
    command_path=$(command_path_or_error "$command_name" brew) || return 1
  fi
  "$command_path" bundle install --file "$root/brew/Brewfile"
}

run_mise_install() {
  local root command_name command_path
  root=$(dotfiles_command_root) || return 1
  if [ "$#" -gt 0 ]; then
    command_path=$1
  else
    command_name=${MISE_CMD-mise}
    command_path=$(command_path_or_error "$command_name" mise) || return 1
  fi
  (
    cd "$root/mise"
    "$command_path" install
  )
}

# Verification helpers intentionally report every independently observable
# discrepancy.  They never create links, directories, backups, or packages.
verify_problem() {
  DOTFILES_VERIFY_FAILURES=$((DOTFILES_VERIFY_FAILURES + 1))
  printf 'Error: %s\n' "$*" >&2
}

verify_manifest_problem() {
  [ "${DOTFILES_VERIFY_SUPPRESS_MANIFEST_ERRORS:-0}" -eq 1 ] || verify_problem "$@"
}

# Resolve DOTFILES_ROOT once per verify invocation.  Keeping the outcome in
# globals prevents three independent checks from reporting an initialization
# failure three times, and ensures the final problem count is meaningful.
verify_dotfiles_root() {
  local root

  if [ "${DOTFILES_VERIFY_ROOT_INITIALIZED:-0}" -eq 1 ]; then
    [ "${DOTFILES_VERIFY_ROOT_VALID:-0}" -eq 1 ]
    return
  fi
  DOTFILES_VERIFY_ROOT_INITIALIZED=1
  DOTFILES_VERIFY_ROOT_VALID=0
  DOTFILES_VERIFY_ROOT=
  if ! root=$(dotfiles_root 2>/dev/null); then
    verify_problem "DOTFILES_ROOT is not a directory: ${DOTFILES_ROOT:-<default>}"
    return 1
  fi
  DOTFILES_VERIFY_ROOT=$root
  DOTFILES_VERIFY_ROOT_VALID=1
}

verify_manifest_path_for_root() {
  local root=$1

  if [ -n "${DOTFILES_MANIFEST:-}" ]; then
    printf '%s\n' "$DOTFILES_MANIFEST"
  else
    printf '%s/manifests/links.tsv\n' "$root"
  fi
}

verify_git_repository() {
  local root

  verify_dotfiles_root || return 1
  root=$DOTFILES_VERIFY_ROOT
  if ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    verify_problem "DOTFILES_ROOT is not a Git repository: $root"
    return 1
  fi
}

# Parse the structural fields needed by the non-mutating checks.  The caller
# supplies a canonical root and consumes VERIFY_MANIFEST_SOURCE/DESTINATION.
verify_manifest_entry() {
  local root=$1 line=$2 source destination remainder tab

  VERIFY_MANIFEST_SOURCE=
  VERIFY_MANIFEST_DESTINATION=
  tab=$(printf '\t')

  case "$line" in
    *"$tab"*) ;;
    *) verify_manifest_problem "manifest entry must have exactly two tab-separated columns: $line"; return 1 ;;
  esac
  source=${line%%"$tab"*}
  remainder=${line#*"$tab"}
  case "$remainder" in
    *"$tab"*) verify_manifest_problem "manifest entry must have exactly two tab-separated columns: $line"; return 1 ;;
  esac
  destination=$remainder

  if [ -z "$source" ] || [ -z "$destination" ]; then
    verify_manifest_problem "manifest source and destination must be nonempty: $line"
    return 1
  fi
  case "$source" in
    /*) verify_manifest_problem "manifest source must be relative: $source"; return 1 ;;
  esac
  case "$destination" in
    /*) verify_manifest_problem "manifest destination must be relative: $destination"; return 1 ;;
  esac
  if path_has_parent_component "$source" || path_has_parent_component "$destination"; then
    verify_manifest_problem "manifest paths may not contain .. components: $line"
    return 1
  fi
  destination=$(normalize_relative_path "$destination") || {
    verify_manifest_problem "manifest destination is empty after normalization: $remainder"
    return 1
  }

  VERIFY_MANIFEST_SOURCE=$source
  VERIFY_MANIFEST_DESTINATION=$destination
}

verify_manifest_sources() {
  local root manifest line source destination resolved_source tab
  local seen_destination seen_destinations status=0

  verify_dotfiles_root || return 1
  root=$DOTFILES_VERIFY_ROOT
  manifest=$(verify_manifest_path_for_root "$root") || return 1
  if [ ! -f "$manifest" ]; then
    verify_problem "manifest does not exist: $manifest"
    return 1
  fi
  if [ ! -r "$manifest" ]; then
    verify_problem "manifest is not readable: $manifest"
    return 1
  fi
  tab=$(printf '\t')
  seen_destination=
  seen_destinations=

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac
    if ! verify_manifest_entry "$root" "$line"; then
      status=1
      continue
    fi
    source=$VERIFY_MANIFEST_SOURCE
    destination=$VERIFY_MANIFEST_DESTINATION

    while IFS= read -r seen_destination || [ -n "$seen_destination" ]; do
      [ -z "$seen_destination" ] && continue
      if [ "$seen_destination" = "$destination" ]; then
        verify_problem "manifest destination is duplicated: $destination"
        status=1
      elif paths_have_parent_child_relationship "$seen_destination" "$destination"; then
        verify_problem "manifest destinations may not be parents or children of each other: $seen_destination and $destination"
        status=1
      fi
    done <<EOF
$seen_destinations
EOF
    if [ -n "${seen_destinations:-}" ]; then
      seen_destinations=$seen_destinations$'\n'$destination
    else
      seen_destinations=$destination
    fi

    if [ ! -e "$root/$source" ]; then
      if [ -L "$root/$source" ]; then
        verify_problem "manifest source is a dangling symlink: $source"
      else
        verify_problem "manifest source does not exist: $source"
      fi
      status=1
      continue
    fi
    if ! resolved_source=$(resolve_existing_path "$root/$source"); then
      verify_problem "manifest source does not resolve: $source"
      status=1
    elif ! path_is_beneath "$resolved_source" "$root"; then
      verify_problem "manifest source escapes DOTFILES_ROOT: $source"
      status=1
    fi
  done <"$manifest"

  return "$status"
}

verify_declared_links() {
  local root manifest home line source destination resolved_source destination_path planned_destination tab
  local seen_destination_path seen_destination_paths status=0 DOTFILES_VERIFY_SUPPRESS_MANIFEST_ERRORS=1

  verify_dotfiles_root || return 1
  root=$DOTFILES_VERIFY_ROOT
  manifest=$(verify_manifest_path_for_root "$root") || return 1
  if [ ! -f "$manifest" ]; then
    return 1
  fi
  if [ ! -d "${HOME:-}" ]; then
    verify_problem "HOME is not a directory: ${HOME:-}"
    return 1
  fi
  if ! home=$(cd "$HOME" && pwd -P); then
    verify_problem "HOME cannot be resolved: $HOME"
    return 1
  fi
  seen_destination_paths=

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac
    # Syntax and source errors were already reported by verify_manifest_sources.
    # Keep checking independently valid entries so one bad line does not hide
    # unrelated broken links.
    if ! verify_manifest_entry "$root" "$line"; then
      status=1
      continue
    fi
    source=$VERIFY_MANIFEST_SOURCE
    destination=$VERIFY_MANIFEST_DESTINATION
    if [ ! -e "$root/$source" ] || ! resolved_source=$(resolve_existing_path "$root/$source"); then
      status=1
      continue
    fi
    if ! path_is_beneath "$resolved_source" "$root"; then
      status=1
      continue
    fi
    destination_path=$home/$destination
    if ! planned_destination=$(resolve_planned_creation_path "$destination_path"); then
      verify_problem "destination cannot be resolved safely: $destination_path"
      status=1
      continue
    fi
    if ! path_is_beneath "$planned_destination" "$home"; then
      verify_problem "managed link destination escapes HOME through a symlink parent: $destination_path"
      status=1
      continue
    fi
    if paths_have_structural_collision "$planned_destination" "$root"; then
      verify_problem "destination collides with managed DOTFILES_ROOT: $planned_destination"
      status=1
      continue
    fi
    while IFS= read -r seen_destination_path || [ -n "$seen_destination_path" ]; do
      [ -z "$seen_destination_path" ] && continue
      if paths_have_structural_collision "$planned_destination" "$seen_destination_path"; then
        verify_problem "manifest destinations resolve to the same or nested physical paths: $planned_destination and $seen_destination_path"
        status=1
      fi
    done <<EOF
$seen_destination_paths
EOF
    if [ -n "$seen_destination_paths" ]; then
      seen_destination_paths=$seen_destination_paths$'\n'$planned_destination
    else
      seen_destination_paths=$planned_destination
    fi
    if ! is_expected_link "$destination_path" "$resolved_source"; then
      verify_problem "managed link is missing or points to a different source: $destination_path (expected $resolved_source)"
      status=1
    fi
  done <"$manifest"

  return "$status"
}

run_brew_bundle_check() {
  local root command_name command_path

  root=$(dotfiles_command_root) || return 1
  if [ "$#" -gt 0 ]; then
    command_path=$1
  else
    command_name=${BREW_CMD-brew}
    command_path=$(command_path_or_error "$command_name" brew) || return 1
  fi
  HOMEBREW_NO_AUTO_UPDATE=1 "$command_path" bundle check --file "$root/brew/Brewfile"
}

run_mise_doctor() {
  local root command_name command_path

  root=$(dotfiles_command_root) || return 1
  if [ "$#" -gt 0 ]; then
    command_path=$1
  else
    command_name=${MISE_CMD-mise}
    command_path=$(command_path_or_error "$command_name" mise) || return 1
  fi
  (
    cd "$root/mise"
    "$command_path" doctor
  )
}
