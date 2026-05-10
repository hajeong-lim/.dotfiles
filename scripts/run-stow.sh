#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
TARGET_DIR="${TARGET_DIR:-$HOME}"
BACKUP_DIR="${BACKUP_DIR:-$DOTFILES_DIR/.backup}"
BACKUP_RUN_DIR="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"

PACKAGES=("$@")
if [ "${#PACKAGES[@]}" -eq 0 ]; then
  PACKAGES=(.)
fi

STOW_ARGS=(-d "$DOTFILES_DIR" -t "$TARGET_DIR" --ignore='^/\.backup($|/)' "${PACKAGES[@]}")

if ! command -v stow >/dev/null 2>&1; then
  echo "stow not found. Install stow before running this script." >&2
  exit 1
fi

stow_output=""
stow_status=0
stow_output="$(stow --simulate "${STOW_ARGS[@]}" 2>&1)" || stow_status=$?

if [ "$stow_status" -ne 0 ]; then
  conflicts=()
  while IFS= read -r target; do
    if [ -n "$target" ]; then
      conflicts+=("$target")
    fi
  done < <(
    printf '%s\n' "$stow_output" | sed -nE \
      -e 's/^  \* existing target is not owned by stow: (.*)$/\1/p' \
      -e 's/^  \* existing target is stowed to a different package: (.*) => .*$/\1/p' \
      -e 's/^  \* cannot stow non-directory .* over existing directory target (.*)$/\1/p' \
      -e 's/^  \* cannot stow directory .* over existing non-directory target (.*)$/\1/p' \
      -e 's/^  \* cannot stow .* over existing target (.*) since .*$/\1/p'
  )

  if [ "${#conflicts[@]}" -eq 0 ]; then
    printf '%s\n' "$stow_output" >&2
    exit "$stow_status"
  fi

  if [ -e "$BACKUP_RUN_DIR" ]; then
    BACKUP_RUN_DIR="$BACKUP_RUN_DIR-$$"
  fi

  for target in "${conflicts[@]}"; do
    case "$target" in
      /*)
        target_path="$target"
        backup_path="$BACKUP_RUN_DIR/${target#/}"
        ;;
      *)
        target_path="$TARGET_DIR/$target"
        backup_path="$BACKUP_RUN_DIR/$target"
        ;;
    esac

    if [ ! -e "$target_path" ] && [ ! -L "$target_path" ]; then
      echo "Skipping missing conflict target: $target_path" >&2
      continue
    fi

    mkdir -p "$(dirname "$backup_path")"
    echo "Backing up $target_path -> $backup_path"
    mv "$target_path" "$backup_path"
  done
fi

stow "${STOW_ARGS[@]}"
