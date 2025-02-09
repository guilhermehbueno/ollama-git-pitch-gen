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
INSTALL_DIR="$HOME/.ollama-git-pitch-gen"

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
    local target="$HOME/.local/bin/pitch"
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
    local model_name="$1"
    local model_file="$INSTALL_DIR/Modelfile.sample"
    local temp_model_file="/tmp/pitch_${model_name}.modelfile"
    local prefixed_model_name="pitch_$model_name"

    # Ensure the template file exists
    if [[ ! -f "$model_file" ]]; then
        error "❌ Template file '$model_file' not found in $INSTALL_DIR"
        exit 1
    fi

    # Check if the model already exists
    if ollama list | grep -q "$prefixed_model_name"; then
        log "✅ Model '$prefixed_model_name' already exists."
        return
    fi

    log "📦 Creating model '$prefixed_model_name' from template..."

    # Replace placeholder in Modelfile.sample and store in a temporary file
    sed "s/<MODEL_NAME>/$model_name/g" "$model_file" > "$temp_model_file"

    # Create the model using the modified template
    ollama create "$prefixed_model_name" -f "$temp_model_file"

    # Verify if the model was created successfully
    if ollama list | grep -q "$prefixed_model_name"; then
        log "✅ Model '$prefixed_model_name' created successfully."
    else
        error "❌ Failed to create model '$prefixed_model_name'."
    fi

    # Cleanup: Remove temporary file
    rm -f "$temp_model_file"
}

uninstall() {
    INSTALL_DIR="$HOME/.ollama-git-pitch-gen"
    rm -rf "$MODEL_DIR"
    unlink "$HOME/.local/bin/pitch"
    log "Uninstalling Ollama and cleaning up..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew >/dev/null 2>&1; then
            brew uninstall ollama
        else
            echo "Homebrew not found. Please uninstall Ollama manually."
        fi
    fi
    rm -rf "$INSTALL_DIR"

}

pitch_model() {
    # Ensure we're inside a Git repository
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -z "$git_root" ]]; then
        echo "❌ Not inside a Git repository."
        exit 1
    fi

    local config_file="$git_root/.git/hooks/prepare-commit-msg.properties"
    local temp_file="$config_file.tmp"

    # Ensure the config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "🔧 Creating configuration file: $config_file"
        touch "$config_file"
    fi

    echo "📦 Available Models in Ollama:"
    
    # Get a numbered list of models
    local models=($(ollama list | grep pitch | awk '{print $1}'))
    
    if [[ ${#models[@]} -eq 0 ]]; then
        echo "❌ No models found in Ollama. Please add models first."
        exit 1
    fi

    for i in "${!models[@]}"; do
        echo "$((i+1)). ${models[i]}"
    done

    # Ask the user to select a model
    read -p "Enter the number of the model you'd like to use: " choice

    # Validate input
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#models[@]} )); then
        echo "❌ Invalid choice. Please enter a valid number."
        exit 1
    fi

    # Get the chosen model
    local selected_model="${models[choice-1]}"
    echo "✅ Selected model: $selected_model"

    # Read the file line by line, replace OLLAMA_MODEL if found
    local updated_lines=()
    local found=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^OLLAMA_MODEL= ]]; then
            updated_lines+=("OLLAMA_MODEL=$selected_model")
            found=1
        else
            updated_lines+=("$line")
        fi
    done < "$config_file"

    # If OLLAMA_MODEL was not found, add it at the end
    if [[ "$found" -eq 0 ]]; then
        updated_lines+=("OLLAMA_MODEL=$selected_model")
    fi

    # Debug: Print final array before writing to the file
    echo "DEBUG: Final updated_lines content:"
    printf "%s\n" "${updated_lines[@]}"

    # Now log the correct updated lines
    log "$config_file"
    log "${updated_lines[@]}"

    # Write back to the properties file
    printf "%s\n" "${updated_lines[@]}" > "$config_file"

    echo "✅ Updated $config_file with OLLAMA_MODEL=$selected_model"
}

delete_models() {
    # Remove Ollama models directory
    rm -rf ~/.ollama/models
    log "Removed Ollama models directory."
}

remove_pitch_models() {
    echo "📦 Fetching all pitch_ models from Ollama..."
    
    # Get a list of models with the "pitch_" prefix
    local models=($(ollama list | grep pitch | awk '{print $1}'))

    # Check if there are any models to remove
    if [[ ${#models[@]} -eq 0 ]]; then
        echo "❌ No pitch_ models found in Ollama."
        return
    fi

    # Confirm before deleting
    echo "🗑 The following models will be removed:"
    for model in "${models[@]}"; do
        echo "   - $model"
    done

    # Loop through models and remove each one
    for model in "${models[@]}"; do
        echo "🗑 Removing model: $model"
        ollama rm "$model"
    done

    echo "✅ All pitch_ models have been removed."
}

update_pitch() {
    echo "🔄 Checking for updates..."
    INSTALL_DIR="$HOME/.ollama-git-pitch-gen"
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo "❌ Installation directory not found. Please reinstall using the install script."
        exit 1
    fi

    cd "$INSTALL_DIR"
    git fetch origin main
    latest_local_commit=$(git rev-parse HEAD)
    latest_remote_commit=$(git rev-parse origin/main)

    if [[ "$latest_local_commit" == "$latest_remote_commit" ]]; then
        echo "✅ You are already up to date!"
    else
        echo "⬆️ Updating to the latest version..."
        git pull origin main
        echo "🎉 Update complete! Run 'pitch info' to verify the latest version."
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
        config_file="$git_root/.git/hooks/prepare-commit-msg.properties"

        if [[ -f "$hook_path" ]]; then
            echo "✅ Git hook installed at $hook_path"
        else
            echo "❌ Git hook NOT installed."
        fi

        # Read the model name from the .properties file
        if [[ -f "$config_file" ]]; then
            model_name=$(grep "^OLLAMA_MODEL=" "$config_file" | cut -d '=' -f2)
            if [[ -n "$model_name" ]]; then
                echo "🤖 Current AI Model: $model_name"
            else
                echo "❌ No model set in $config_file."
            fi
        else
            echo "❌ Configuration file not found: $config_file"
        fi

    else
        echo "❌ Not inside a Git repository."
    fi

    # Check if the symlink exists for the pitch executable
    symlink_target="$HOME/.local/bin/pitch"
    if [[ -L "$symlink_target" ]]; then
        echo "🔗 Symlink for pitch is set up at: $(readlink -f "$symlink_target")"
    else
        echo "❌ Symlink for pitch is NOT set up."
    fi

    # Check latest commit hash and recommend updates
    install_dir="$HOME/.ollama-git-pitch-gen"
    if [[ -d "$install_dir" ]]; then
        cd "$install_dir"
        latest_local_commit=$(git rev-parse HEAD)
        latest_remote_commit=$(git ls-remote origin -h refs/heads/main | awk '{print $1}')

        echo "🔍 Latest installed commit: $latest_local_commit"
        if [[ "$latest_local_commit" != "$latest_remote_commit" ]]; then
            echo "⚠️ A new update is available. Run 'pitch update' to get the latest version."
        else
            echo "✅ Your installation is up to date."
        fi
    else
        echo "❌ Installation directory not found: $install_dir"
    fi
}

# Function to generate a PR description in Markdown
generate_pr_markdown() {
    local base_branch="$1"
    local branch_name
    local diff_content
    local model_name
    local config_file=".git/hooks/prepare-commit-msg.properties"

    # Validate that base_branch is provided
    if [[ -z "$base_branch" ]]; then
        echo "❌ Error: No base branch provided."
        echo "Usage: pitch pr <base_branch>"
        echo "Example: pitch pr main"
        exit 1
    fi

    # Get the current Git branch name
    branch_name=$(git rev-parse --abbrev-ref HEAD)

    # Get the AI model from the properties file
    if [[ -f "$config_file" ]]; then
        model_name=$(grep "^OLLAMA_MODEL=" "$config_file" | cut -d '=' -f2)
    else
        model_name="pitch_default"  # Default fallback model
    fi

    echo "🤖 Using AI Model: $model_name"

    # Get the Git diff between base branch and the current branch
    echo "🔍 Comparing $base_branch to $branch_name..."
    diff_content=$(git diff $base_branch..$branch_name --unified=3 --no-color | tail -n 100)

    if [[ -z "$diff_content" ]]; then
        echo "❌ No differences found between $base_branch and $branch_name."
        exit 1
    fi

    # Send the diff to Ollama for PR generation
    echo "📨 Sending Git diff to Ollama for PR title and summary..."
    ollama run "$model_name" "Generate a concise Pull Request title and summary. Ensure the output follows strict Markdown formatting:

Generate a concise Pull Request title and summary in Markdown format for the following Git diff:

$diff_content

Format output as:
# <PR Title>

## 📌 Summary
<PR Summary>

## 🔄 Changes Made
- List modified files

## 🛠 How to Test
1. Steps to validate the changes

## ✅ Checklist
- [ ] Code follows project guidelines
- [ ] Tests have been added/updated
- [ ] Documentation is updated if needed

## 📜 Related Issues / Tickets
- Fixes #...

## 📝 Additional Notes
- Any extra information reviewers should know" 
}

# ───────────────────────────────────────────────────────────
# 🔹 SCRIPT EXECUTION LOGIC
# ───────────────────────────────────────────────────────────

case "$1" in
    install)
        install_ollama
        start_ollama
        # download_model
        register_symlink
        create_model llama3.2
        create_model llama3.1:latest
        create_model deepseek-coder:latest
        ;;
    uninstall)
        remove_pitch_models
        stop_ollama
        uninstall
        log "Uninstallation complete."
        ;;
    delete)
        delete_models
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
    model)
        pitch_model
        ;;
    update)
        update_pitch
        ;;
    create_model)
        create_model $2
        ;;
    pr)
        generate_pr_markdown $2
        ;;
    *)
        echo "Usage: $0 {install|uninstall|start|stop|info|apply|delete}"
        exit 1
        ;;
esac