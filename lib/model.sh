
# ───────────────────────────────────────────────────────────
# 🔹 MODEL MANAGEMENT FUNCTIONS
# ───────────────────────────────────────────────────────────

check_model_exists() {
    local model_name="$1"
    local git_root=$(get_git_repo_root)
    local config_file="$git_root/.git/hooks/prepare-commit-msg.properties"

    if [[ "$model_name" == "openai/"* ]]; then
        # Check if model name is just "openai/" or "openai/ "
        if [[ "$model_name" == "openai/" || "$model_name" =~ ^openai/\s*$ ]]; then
            echo "❌ OpenAI model name is missing. Please run 'pitch model' to select a valid OpenAI model."
            exit 1
        fi
        if ! grep -q "^OPENAI_API_KEY=" "$config_file" || [[ -z $(grep "^OPENAI_API_KEY=" "$config_file" | cut -d'=' -f2-) ]]; then
            echo "❌ OpenAI API key not found or not set. Please run 'pitch model' to configure it."
            exit 1
        fi
        log "✅ OpenAI model and API key configured."
    elif ! ollama list | grep -q "$model_name"; then
        echo "❌ Ollama model '$model_name' not found. Please run 'pitch model' to select a valid model or ensure Ollama is running."
        exit 1
    else
        log "✅ Ollama model '$model_name' found."
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
    check_model_exists "$prefixed_model_name"
    # Cleanup: Remove temporary file
    rm -f "$temp_model_file"
}


download_model() {
    if ollama list | grep -q "$MODEL_NAME"; then
        log "Model '$MODEL_NAME' already exists locally."
    else
        log "Downloading model '$MODEL_NAME'..."
        ollama pull "$HUGGINGFACE_URL" || error "Failed to download model."
    fi
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
    git_root=$(get_git_repo_root)
    local config_file="$git_root/.git/hooks/prepare-commit-msg.properties"

    # Ensure the config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "🔧 Creating configuration file: $config_file"
        touch "$config_file"
    fi

    echo "🤖 Choose your AI provider:"
    local provider=$(gum choose "Ollama" "OpenAI" --header "Select AI provider:")

    if [[ "$provider" == "OpenAI" ]]; then
        local openai_model_name=$(gum input --placeholder "Enter OpenAI model name (e.g., gpt-4)")
        if [[ -z "$openai_model_name" ]]; then
            echo "❌ OpenAI model name cannot be empty."
            exit 1
        fi
        local openai_api_key=$(gum input --password --placeholder "Enter your OpenAI API Key")
        if [[ -z "$openai_api_key" ]]; then
            echo "❌ OpenAI API Key cannot be empty."
            exit 1
        fi

        local model_to_save="openai/$openai_model_name"

        # Update OLLAMA_MODEL in config file
        if grep -q "^OLLAMA_MODEL=" "$config_file"; then
            sed -i.bak "s|^OLLAMA_MODEL=.*|OLLAMA_MODEL=$model_to_save|" "$config_file"
        else
            echo "OLLAMA_MODEL=$model_to_save" >> "$config_file"
        fi

        # Update OPENAI_API_KEY in config file
        if grep -q "^OPENAI_API_KEY=" "$config_file"; then
            sed -i.bak "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=$openai_api_key|" "$config_file"
        else
            echo "OPENAI_API_KEY=$openai_api_key" >> "$config_file"
        fi
        rm -f "$config_file.bak" # Remove backup file created by sed

        echo "✅ Configured to use OpenAI model: $model_to_save"
        echo "✅ OpenAI API Key stored in $config_file"

    elif [[ "$provider" == "Ollama" ]]; then
        echo "📦 Available Models in Ollama:"
        local models=($(ollama list | grep pitch | awk '{print $1}'))
        
        if [[ ${#models[@]} -eq 0 ]]; then
            echo "❌ No 'pitch_' prefixed models found in Ollama. Please add models using 'ollama create ... -f Modelfile.sample' or ensure they have the 'pitch_' prefix."
            exit 1
        fi

        local selected_model=$(printf "%s\n" "${models[@]}" | gum choose --header "Select an Ollama model:" --cursor "➜")
        if [[ -z "$selected_model" ]]; then
            echo "❌ No model selected."
            exit 1
        fi
        echo "✅ Selected Ollama model: $selected_model"

        # Update OLLAMA_MODEL in config file
        if grep -q "^OLLAMA_MODEL=" "$config_file"; then
            sed -i.bak "s|^OLLAMA_MODEL=.*|OLLAMA_MODEL=$selected_model|" "$config_file"
        else
            echo "OLLAMA_MODEL=$selected_model" >> "$config_file"
        fi
        # Remove OPENAI_API_KEY if it exists, as we are using Ollama
        if grep -q "^OPENAI_API_KEY=" "$config_file"; then
            sed -i.bak "/^OPENAI_API_KEY=/d" "$config_file"
        fi
        rm -f "$config_file.bak" # Remove backup file created by sed

        echo "✅ Updated $config_file with OLLAMA_MODEL=$selected_model"
    else
        echo "❌ Invalid provider selected."
        exit 1
    fi
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