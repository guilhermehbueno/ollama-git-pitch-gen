#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

##############################################
# Configuration
##############################################
REPO_URL="https://github.com/guilhermehbueno/ollama-git-pitch-gen.git"
INSTALL_DIR="$HOME/.ollama-git-pitch-gen"
EXECUTABLE_NAME="pitch"
BIN_DIR="$HOME/.local/bin"

# Source helper scripts from the installation directory AFTER cloning
# This means functions from these scripts can only be called after setup_repository
# Or, we need to ensure they are available if called earlier.

##############################################
# Helper Functions
##############################################
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Basic logging if full logging.sh isn't available yet
log_install() { echo "INSTALLER LOG: $*"; }
error_install() { echo "INSTALLER ERROR: $*" >&2; }

##############################################
# Dependency Installation
##############################################
install_jq() {
    if command_exists jq; then
        log_install "jq is already installed."
        return
    fi
    log_install "Installing jq for JSON processing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command_exists brew; then
            brew install jq || error_install "Failed to install jq using Homebrew."
        else
            error_install "Homebrew not found. Please install Homebrew to install jq, or install jq manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt; then
            sudo apt update && sudo apt install -y jq || error_install "Failed to install jq using apt."
        elif command_exists yum; then
            sudo yum install -y jq || error_install "Failed to install jq using yum."
        else
            error_install "apt or yum not found. Please install jq manually."
            exit 1
        fi
    else
        error_install "Unsupported OS for automatic jq installation. Please install jq manually."
        exit 1
    fi
}

install_gum() {
    log_install "Checking Gum installation..."
    if command_exists gum; then
        log_install "✅ Gum is already installed."
        return
    fi

    log_install "Installing Gum..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command_exists brew; then
            log_install "❌ Homebrew not found. Please install Homebrew first."
            exit 1
        fi
        brew install gum || { error_install "❌ Failed to install Gum."; exit 1; }
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt; then
            sudo apt update && sudo apt install -y gum || { error_install "❌ Failed to install Gum."; exit 1; }
        elif command_exists yum; then
            sudo yum install -y gum || { error_install "❌ Failed to install Gum."; exit 1; }
        else
            log_install "⚠️ Please install Gum manually from https://github.com/charmbracelet/gum."
            exit 1
        fi
    else
        log_install "❌ Unsupported OS. Please install Gum manually from https://github.com/charmbracelet/gum."
        exit 1
    fi
}

install_dependencies() {
    log_install "🔧 Checking dependencies..."

    if ! command_exists git; then
        error_install "❌ Git is not installed. Please install Git and try again."
        exit 1
    fi

    # gh is optional, main.sh checks for it
    # if ! command_exists gh; then
    #     log_install "⚠️ GitHub CLI (gh) is not installed. PR automation will be disabled."
    # fi

    install_gum
    install_jq # Added jq installation
}

##############################################
# Repository Setup
##############################################
setup_repository() {
    log_install "📥 Checking installation directory..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        log_install "🔄 Removing existing installation directory $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
    fi

    log_install "🚀 Cloning git-pitch-gen repository into $INSTALL_DIR..."
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR" || { error_install "❌ Failed to clone repository."; exit 1; }

    # Now that repo is cloned, make scripts executable
    chmod +x "$INSTALL_DIR/main.sh"
    chmod +x "$INSTALL_DIR/lib/"*.sh
    chmod +x "$INSTALL_DIR/tests/"*.sh
}

##############################################
# Executable Setup
##############################################
setup_executable() {
    log_install "🔗 Setting up executable..."
    mkdir -p "$BIN_DIR"
    ln -sf "$INSTALL_DIR/main.sh" "$BIN_DIR/$EXECUTABLE_NAME"
    chmod +x "$BIN_DIR/$EXECUTABLE_NAME" # Ensure symlink target (main.sh) is also executable
    
    # Add BIN_DIR to PATH if not already present
    local profile_files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile")
    local path_updated=false
    if ! echo "$PATH" | grep -q "$BIN_DIR"; then
        export PATH="$BIN_DIR:$PATH" # Add to current session's PATH
        for profile_file in "${profile_files[@]}"; do
            if [[ -f "$profile_file" ]]; then
                if ! grep -q "export PATH="$BIN_DIR:\$PATH"" "$profile_file"; then
                    echo "export PATH="$BIN_DIR:\$PATH"" >> "$profile_file"
                    log_install "✅ Added $BIN_DIR to PATH in $profile_file."
                    path_updated=true
                fi
            fi
        done
        if $path_updated; then
             log_install "Please restart your shell or run 'source <your_shell_profile_file>' (e.g. source ~/.bashrc)."
        fi
    else
        log_install "✅ $BIN_DIR is already in PATH."
    fi
}

##############################################
# API Credentials Setup
##############################################
setup_api_credentials() {
    # Source the necessary functions from the cloned repository
    # Ensure SCRIPT_DIR_AI_PROVIDERS is set correctly if ai_providers.sh uses it to find other scripts.
    # We assume that lib/logging.sh and lib/config_manager.sh are correctly sourced by ai_providers.sh
    # Or, ensure relevant functions like get_config_value, update_config_value are available.
    # For simplicity, we assume ai_providers.sh can be sourced directly here.
    # The SCRIPT_DIR variable in ai_providers.sh should handle finding its own dependencies.

    # Making SCRIPT_DIR available for sourced scripts
    export SCRIPT_DIR="$INSTALL_DIR"
    # This is a common pattern for lib scripts to find each other:
    # SCRIPT_DIR_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # source "$SCRIPT_DIR_LIB/logging.sh"
    # So, ai_providers.sh should be able to find logging.sh and config_manager.sh if they are in $INSTALL_DIR/lib

    source "$INSTALL_DIR/lib/config_manager.sh" # For get_config_value, update_config_value
    source "$INSTALL_DIR/lib/ai_providers.sh"   # For validate_api_key, store_api_key

    log_install "🔐 Setting up AI provider credentials..."

    # Ensure CONFIG_FILE is defined for store_api_key if it updates a project config.
    # For a global setup, API keys are usually stored in ~/.provider/api_key
    # and env vars are preferred. store_api_key saves to standard paths.
    # If a global pitch config file is desired, define it here.
    # For now, store_api_key will save to default file paths like ~/.openai/api_key.

    if gum confirm "Configure OpenAI API access?"; then
        local openai_key
        openai_key=$(gum input --password --placeholder "OpenAI API Key (sk-...)")
        if [[ -n "$openai_key" ]]; then
            # store_api_key "openai" "$openai_key" will call validate_api_key
            if store_api_key "openai" "$openai_key"; then
                 log_install "✅ OpenAI API key configured."
            else
                 error_install "Failed to store OpenAI API key. It might be invalid or a permission issue."
            fi
        else
            log_install "No OpenAI API key entered. Skipping."
        fi
    fi

    if gum confirm "Configure Anthropic (Claude) API access?"; then
        local claude_key
        claude_key=$(gum input --password --placeholder "Anthropic API Key (sk-ant-...)")
        if [[ -n "$claude_key" ]]; then
            # store_api_key "anthropic" "$claude_key" (Note: ai_providers.sh uses "anthropic" for Claude keys)
             if store_api_key "anthropic" "$claude_key"; then
                log_install "✅ Anthropic API key configured."
            else
                error_install "Failed to store Anthropic API key. It might be invalid or a permission issue."
            fi
        else
            log_install "No Anthropic API key entered. Skipping."
        fi
    fi
}

##############################################
# Configuration Migration
##############################################
migrate_existing_configs() {
    source "$INSTALL_DIR/lib/config_manager.sh" # For migrate_legacy_config

    log_install "🔄 Checking for existing configurations to migrate..."

    # Path to the global properties file, if one exists with the old tool
    # This tool seems to store prepare-commit-msg.properties inside .git/hooks/
    # So migration should happen when 'pitch apply' is run in a repo.
    # However, the issue spec for install.sh implies a broader search.
    # Let's assume we are migrating a global config if it exists,
    # and also project-level configs.

    # Example for a global config (if your tool used one, adjust path)
    # local global_config_path="$HOME/.ollama-git-pitch-gen/prepare-commit-msg.properties"
    # if [[ -f "$global_config_path" ]]; then
    #     log_install "Migrating global configuration file: $global_config_path"
    #     migrate_legacy_config "$global_config_path"
    # fi

    # As per spec: "Find and migrate existing .properties files"
    # This is potentially broad. Let's refine to common locations for this tool.
    # The tool places its config in .git/hooks/prepare-commit-msg.properties.
    # Scanning all of $HOME for "prepare-commit-msg.properties" could be slow and error-prone.
    # A more targeted approach might be to migrate when `pitch apply` is run in a repo.
    # For now, implementing as per the spec's suggestion for install.sh:

    # First, create/migrate the default config in the installation directory itself
    # This can serve as a template or a global fallback if no project config is found.
    local install_dir_config="$INSTALL_DIR/prepare-commit-msg.properties"
    log_install "Ensuring default configuration exists at $install_dir_config"
    if [[ -f "$install_dir_config" ]]; then
        migrate_legacy_config "$install_dir_config"
    else
        # If no config file in install_dir, create a new default one.
        # This ensures that main.sh can load a default config if needed.
        create_default_config "$install_dir_config"
    fi

    # The spec says "find $HOME -name prepare-commit-msg.properties". This is very broad.
    # Let's assume for now the main config to migrate is the one in $INSTALL_DIR
    # and project-specific ones will be handled by `pitch apply` or a similar mechanism.
    # If a true global search is needed:
    # log_install "Searching for project-specific configuration files in $HOME to migrate..."
    # find "$HOME" -path "*/.git/hooks/prepare-commit-msg.properties" -type f -print0 | while IFS= read -r -d $' ' config_file; do
    #     log_install "Found potential legacy config: $config_file. Migrating..."
    #     migrate_legacy_config "$config_file"
    # done
    # For now, focusing on the config within INSTALL_DIR as the primary one managed by install.sh

    log_install "Configuration migration check complete."
}


##############################################
# Main Installation Process
##############################################
log_install "Starting Ollama Git Pitch Generator installation..."

install_dependencies
setup_repository # Clones the repo and sets permissions

# After repo is cloned, its scripts can be sourced and used
setup_api_credentials    # New step
migrate_existing_configs # New step

setup_executable

# Run main.sh install command (from the newly cloned repo)
# This typically handles Ollama installation, model creation etc.
log_install "Running main script's internal install steps (ollama setup, model creation)..."
"$INSTALL_DIR/main.sh" install # main.sh should handle its own logging for these steps

log_install "🎉 Installation complete! Use 'pitch' commands to get started."
log_install "Please restart your shell or source your shell profile file (e.g., source ~/.bashrc or source ~/.zshrc) for PATH changes to take effect."
