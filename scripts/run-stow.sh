#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
TARGET_DIR="${TARGET_DIR:-$HOME}"
BACKUP_DIR="${BACKUP_DIR:-$DOTFILES_DIR/.backup}"
BACKUP_RUN_DIR="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"
MOVED=0

STOW_IGNORE=(
  # --ignore='^[^.].*'
  --ignore='^\.backup($|/)'
  --ignore='^\.git($|/)'
  --ignore='^\.gitignore$'
  --ignore='^\.gitmodules$'
  --ignore='^\.stow-local-ignore$'
  --ignore='^\.DS_Store$'
  --ignore='^\.vscode($|/)'
)

if ! command -v stow >/dev/null 2>&1; then
  echo "stow not found. Install stow before running this script." >&2
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "Target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

for source in "$DOTFILES_DIR"/.[!.]* "$DOTFILES_DIR"/..?*; do
  [ -e "$source" ] || [ -L "$source" ] || continue

  name="$(basename "$source")"
  case "$name" in
    .backup|.git|.gitignore|.gitmodules|.stow-local-ignore|.DS_Store|.vscode)
      continue
      ;;
  esac

  target="$TARGET_DIR/$name"
  [ -e "$target" ] || [ -L "$target" ] || continue
  [ "$target" -ef "$source" ] && continue

  mkdir -p "$BACKUP_RUN_DIR"
  echo "Backing up $target -> $BACKUP_RUN_DIR/$name"
  mv "$target" "$BACKUP_RUN_DIR/$name"
  MOVED=1
done

stow -R -d "$DOTFILES_DIR" -t "$TARGET_DIR" "${STOW_IGNORE[@]}" .

echo "Dotfiles stowed into $TARGET_DIR"

if [ "$MOVED" -eq 1 ]; then
  echo "Backups saved in $BACKUP_RUN_DIR"
fi
