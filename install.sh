#!/bin/bash -u

# Install Homebrew on macOS if not installed
if [ "$(uname -s)" = "Darwin" ]; then
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Installing Homebrew..." >&2
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi


# Initalize package manager, and define `install_pkg` function
if command -v brew &>/dev/null; then
    brew update
    install_pkg (){ brew install "$1"; }

elif command -v apt-get &>/dev/null; then
    sudo apt-get update
    install_pkg (){ sudo apt-get install -y "$1"; }

elif command -v pacman &>/dev/null; then
    sudo pacman -Syu
    install_pkg (){ sudo pacman -Syu --noconfirm "$1"; }

elif command -v dnf &>/dev/null; then
    sudo dnf check-update
    install_pkg (){ sudo dnf install -y "$1"; }

else
    echo "Package manager not found. Please install brew, apt-get, pacman, or dnf." >&2
    exit 1
fi

install_pkg stow

# Install my .dotfiles repository
if [ ! -d "$HOME/.dotfiles" ]; then
    git clone --depth 1 https://github.com/doolim98/.dotfiles.git ~/.dotfiles
fi

# stow my dotfiles
(
    cd "$HOME/.dotfiles"
    stow --adopt --no-folding .
)

# Install .my.bashrc and .my.zshrc
SNIPPET_INSTALL_MY_BASHRC='source ~/.my.bashrc'
SNIPPET_INSTALL_MY_ZSHRC='source ~/.my.zshrc'

touch ~/.bashrc
touch ~/.zshrc

if ! grep -Fxq "$SNIPPET_INSTALL_MY_BASHRC" ~/.bashrc; then
    echo "$SNIPPET_INSTALL_MY_BASHRC" >> ~/.bashrc
fi

if ! grep -Fxq "$SNIPPET_INSTALL_MY_ZSHRC" ~/.zshrc; then
    echo "$SNIPPET_INSTALL_MY_ZSHRC" >> ~/.zshrc
fi

# Install Starship
if ! command -v starship &>/dev/null; then
    curl -sS https://starship.rs/install.sh | sh
fi


echo "

.dotfiles: Installation complete. Please restart your shell. Current \$SHELL=$SHELL

"