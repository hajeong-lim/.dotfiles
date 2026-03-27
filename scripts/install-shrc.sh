#!/usr/bin/env bash

set -e

DOTFILES_DIR="$HOME/.dotfiles"

add_source_line() {
  local rc_file="$1"
  local source_file="$2"
  local line="source $source_file"

  if [ ! -f "$rc_file" ]; then
    touch "$rc_file"
    echo "Created $rc_file"
  fi

  if grep -qF "$line" "$rc_file"; then
    echo "Already present in $rc_file"
  else
    echo "" >> "$rc_file"
    echo "$line" >> "$rc_file"
    echo "Added to $rc_file"
  fi
}

add_source_line "$HOME/.bashrc" "$DOTFILES_DIR/.my.bashrc"
add_source_line "$HOME/.zshrc"  "$DOTFILES_DIR/.my.zshrc"
