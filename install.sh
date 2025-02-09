#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

##############################################
# Configuration
##############################################
REPO_URL="https://github.com/guilhermehbueno/ollama-git-pitch-gen.git"
INSTALL_DIR="$HOME/.ollama-git-pitch-gen"
EXECUTABLE_NAME="pitch"
BIN_DIR="$HOME/.local/bin"

##############################################
# Helper Functions
##############################################
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

##############################################
# Dependency Installation
##############################################
install_dependencies() {
    echo "🔧 Checking dependencies..."
    
    if ! command_exists git; then
        echo "❌ Git is not installed. Please install Git and try again."
        exit 1
    fi
    
    if ! command_exists gh; then
        echo "⚠️ GitHub CLI (gh) is not installed. PR automation will be disabled."
    fi
}

##############################################
# Repository Setup
##############################################
setup_repository() {
    echo "📥 Checking installation directory..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        echo "🔄 Removing existing installation..."
        rm -rf "$INSTALL_DIR"
    fi

    echo "🚀 Cloning git-pitch-gen repository into $INSTALL_DIR..."
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR" || { echo "❌ Failed to clone repository."; exit 1; }
}

##############################################
# Executable Setup
##############################################
setup_executable() {
    echo "🔗 Setting up executable..."
    mkdir -p "$BIN_DIR"
    ln -sf "$INSTALL_DIR/main.sh" "$BIN_DIR/$EXECUTABLE_NAME"
    chmod +x "$BIN_DIR/$EXECUTABLE_NAME"
    
    if ! echo "$PATH" | grep -q "$BIN_DIR"; then
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$HOME/.bashrc"
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$HOME/.zshrc"
        echo "✅ Added $BIN_DIR to PATH. Restart your shell or run 'source ~/.bashrc' or 'source ~/.zshrc'"
    else
        echo "✅ $BIN_DIR is already in PATH."
    fi
}

##############################################
# Main Installation Process
##############################################
install_dependencies
setup_repository
setup_executable

# Run main.sh install
"$INSTALL_DIR/main.sh" install

echo "🎉 Installation complete! Use 'pitch' commands to get started."
