#!/bin/bash

# ───────────────────────────────────────────────────────────
# 🔹 GLOBAL VARIABLES
# ───────────────────────────────────────────────────────────

MODEL_NAME="lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF"  # Replace with your Hugging Face model name
HUGGINGFACE_URL="https://huggingface.co/lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF"  # Model URL
MODEL_DIR="$HOME/models"  # Directory to store the model
MODEL_PATH="git-assistant"  # Model alias for Ollama
SYSTEM_PROMPT="You are an AI expert in answering questions accurately."
CONFIG_FILE=".git/prepare-commit-msg.properties"

# ───────────────────────────────────────────────────────────
# 🔹 HELPER FUNCTIONS
# ───────────────────────────────────────────────────────────

log() {
    echo -e "\033[1;34m[INFO]\033[0m $1"  # Blue color
}

warn() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"  # Yellow color
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"  # Red color
    exit 1
}

# ───────────────────────────────────────────────────────────
# 🔹 INSTALLATION FUNCTIONS
# ───────────────────────────────────────────────────────────

install_ollama() {
    log "Checking Ollama installation..."
    if command -v ollama >/dev/null 2>&1; then
        log "Ollama is already installed."
        return
    fi

    log "Installing Ollama..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew >/dev/null 2>&1; then
            error "Homebrew not found. Please install Homebrew first."
        fi
        brew install ollama || error "Failed to install Ollama."
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        warn "Please install Ollama manually from https://ollama.ai."
        exit 1
    else
        error "Unsupported OS. Please install Ollama manually from https://ollama.ai."
    fi
}

install_git_hook() {
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -z "$git_root" ]]; then
        error "Not inside a Git repository."
    fi

    local hook_file="$git_root/.git/hooks/prepare-commit-msg"
    local script_dir
    script_dir=$(dirname "$(realpath "$0")")

    local hook_source="$script_dir/prepare-commit-msg.sh"
    local hook_properties="$script_dir/prepare-commit-msg.properties"

    if [[ ! -f "$hook_source" ]]; then
        error "Hook script '$hook_source' not found."
    fi

    log "Installing Git hook..."
    cp "$hook_source" "$hook_file"
    cp "$hook_properties" "$hook_file.properties"
    chmod +x "$hook_file"

    log "Git hook installed successfully."
    log "- $hook_file"
    log "- $hook_properties"
}

register_symlink() {
    local target="$HOME/.local/bin/git-pitch-gen"
    mkdir -p "$HOME/.local/bin"

    if [[ -L "$target" ]]; then
        log "Symlink already exists at $target."
    else
        log "Creating symlink: $target -> $PWD/main.sh"
        ln -s "$PWD/main.sh" "$target"
        chmod +x "$target"
    fi
}

# ───────────────────────────────────────────────────────────
# 🔹 OLLAMA SERVER CONTROL FUNCTIONS
# ───────────────────────────────────────────────────────────

start_ollama() {
    if pgrep -f "ollama serve" >/dev/null; then
        log "Ollama is already running."
    else
        log "Starting Ollama server..."
        nohup ollama serve > ~/.ollama_server.log 2>&1 &
        log "Ollama started successfully."
    fi
}

stop_ollama() {
    if pkill -f "ollama serve"; then
        log "Ollama server stopped."
    else
        warn "No running Ollama server found."
    fi
}

# ───────────────────────────────────────────────────────────
# 🔹 MODEL MANAGEMENT FUNCTIONS
# ───────────────────────────────────────────────────────────

download_model() {
    if ollama list | grep -q "$MODEL_NAME"; then
        log "Model '$MODEL_NAME' already exists locally."
    else
        log "Downloading model '$MODEL_NAME'..."
        ollama pull "$HUGGINGFACE_URL" || error "Failed to download model."
    fi
}

create_model() {
    local model_file=$1
    local model_name=$2
    if ollama list | grep -q "$model_name"; then
        log "Model '$model_name' already exists."
    else
        ollama create "$model_name" -f "$model_file" || error "Failed to create model '$model_name'."
        log "Model '$model_name' created successfully."
    fi
}

# ───────────────────────────────────────────────────────────
# 🔹 SYSTEM INFO FUNCTION
# ───────────────────────────────────────────────────────────

info() {
    log "Gathering system and installation information..."

    echo "🖥️  OS: $(uname -a)"
    echo "💻 Shell: $SHELL"

    if command -v ollama >/dev/null 2>&1; then
        echo "✅ Ollama installed: $(ollama --version)"
    else
        echo "❌ Ollama is NOT installed."
    fi

    if pgrep -f "ollama serve" >/dev/null; then
        echo "✅ Ollama server is running."
    else
        echo "❌ Ollama server is NOT running."
    fi

    echo "📦 Available Models:"
    ollama list 2>/dev/null | grep -v "GIN" || echo "❌ No models found."

    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$git_root" ]]; then
        hook_path="$git_root/.git/hooks/prepare-commit-msg"
        if [[ -f "$hook_path" ]]; then
            echo "✅ Git hook installed at $hook_path"
        else
            echo "❌ Git hook NOT installed."
        fi
    else
        echo "❌ Not inside a Git repository."
    fi
}

# ───────────────────────────────────────────────────────────
# 🔹 SCRIPT EXECUTION LOGIC
# ───────────────────────────────────────────────────────────

case "$1" in
    install)
        install_ollama
        download_model
        register_symlink
        ;;
    uninstall)
        stop_ollama
        rm -rf "$MODEL_DIR"
        log "Uninstallation complete."
        ;;
    start)
        start_ollama
        ;;
    stop)
        stop_ollama
        ;;
    info)
        info
        ;;
    apply)
        install_git_hook
        ;;
    *)
        echo "Usage: $0 {install|uninstall|start|stop|info|apply}"
        exit 1
        ;;
esac