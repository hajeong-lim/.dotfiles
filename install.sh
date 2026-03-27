#!/bin/bash

set -eu

# Install my .dotfiles repository
if [ ! -d "$HOME/.dotfiles" ]; then
    git clone https://github.com/hajeong-lim/.dotfiles.git ~/.dotfiles
fi

cd "$HOME/.dotfiles"


./scripts/install-shrc.sh


if ! command -v stow &>/dev/null; then
    echo "Stow not found. Installing stow..."
    ./scripts/install-stow.sh
fi

stow .