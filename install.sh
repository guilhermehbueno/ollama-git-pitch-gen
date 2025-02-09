#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Define variables
REPO_URL="https://github.com/guilhermehbueno/ollama-git-pitch-gen.git"
INSTALL_DIR="$HOME/.ollama-git-pitch-gen"
EXECUTABLE_NAME="pitch"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install dependencies
install_dependencies() {
    echo "🔧 Checking dependencies..."
    
    if ! command_exists git; then
        echo "❌ Git is not installed. Please install Git and try again."
        exit 1
    fi
    
    if ! command_exists ollama; then
        echo "❌ Ollama is not installed. Please install it from https://ollama.ai and try again."
        exit 1
    fi
    
    if ! command_exists gh; then
        echo "⚠️ GitHub CLI (gh) is not installed. PR automation will be disabled."
    fi
}

# Function to clone or update the repository
setup_repository() {
    echo "📥 Checking installation directory..."
    
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo "🚀 Cloning git-pitch-gen repository into $INSTALL_DIR..."
        git clone --depth=1 "$REPO_URL" "$INSTALL_DIR" || { echo "❌ Failed to clone repository."; exit 1; }
    else
        echo "✅ Repository already exists at $INSTALL_DIR. Updating..."
        cd "$INSTALL_DIR" && git pull origin main
    fi
}

# Function to set up executable
setup_executable() {
    echo "🔗 Setting up executable..."
    ln -sf "$INSTALL_DIR/main.sh" "$HOME/.local/bin/$EXECUTABLE_NAME"
    chmod +x "$HOME/.local/bin/$EXECUTABLE_NAME"
    
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
        echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> "$HOME/.zshrc"
        echo "✅ Added $HOME/.local/bin to PATH. Restart your shell or run 'source ~/.bashrc' or 'source ~/.zshrc'"
    fi
}

# Function to set up Git hooks
setup_git_hooks() {
    echo "🛠 Setting up Git hooks..."
    "$INSTALL_DIR/main.sh" apply
}

# Main installation process
install_dependencies
setup_repository
setup_executable
setup_git_hooks

echo "🎉 Installation complete! Use 'pitch' commands to get started."
