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
