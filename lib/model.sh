
# ───────────────────────────────────────────────────────────
# 🔹 MODEL MANAGEMENT & SELECTION (Multi-Provider)
# ───────────────────────────────────────────────────────────

# Helper function to select a model for a given provider
select_ai_model() {
    local provider="$1"
    if [[ -z "$provider" ]]; then
        error "Provider name required for model selection."
        return 1
    fi

    local models_list
    models_list=$(get_models_for_provider "$provider") # From ai_providers.sh
    if [[ -z "$models_list" ]]; then
        error "No models found or configured for provider: $provider."
        # For Ollama, prompt to create one if none exist
        if [[ "$provider" == "ollama" ]]; then
            if gum confirm "No Ollama models found. Would you like to try creating a default one (pitch_llama3.1:latest)?"; then
                create_model "llama3.1:latest" # Assumes create_model is available (Ollama specific)
                models_list=$(get_models_for_provider "$provider") # Try again
                if [[ -z "$models_list" ]]; then
                     error "Still no Ollama models after creation attempt. Please check Ollama setup."
                     return 1
                fi
            else
                return 1
            fi
        else
             error "For $provider, ensure models are listed in ai_providers.sh or API is accessible."
             return 1
        fi
    fi

    log "Available models for $provider:"
    echo "$models_list" # Show the list before gum choose for clarity

    local selected_model
    selected_model=$(echo "$models_list" | gum choose --header "Select Model for $provider:")

    if [[ -z "$selected_model" ]]; then
        error "No model selected for $provider."
        return 1
    fi
    echo "$selected_model"
}
# ───────────────────────────────────────────────────────────
# 🔹 MODEL MANAGEMENT FUNCTIONS
# ───────────────────────────────────────────────────────────

check_model_exists() { # This is Ollama specific
    local model_name_to_check="$1" # Renamed to avoid conflict with other model_name variables
    if ! ollama list | awk '{print $1}' | grep -q -x "$model_name_to_check"; then
        error "❌ Ollama Model '$model_name_to_check' not found. Active Ollama models are:"
        ollama list | awk '{print $1}' | tail -n +2 # Show available models
        error "You can try 'ollama pull $model_name_to_check' or 'pitch create_model <base_model_for_$model_name_to_check>'."
        return 1
    fi
    return 0
}

# ───────────────────────────────────────────────────────────
# 🔹 PROVIDER CREDENTIALS & STATUS
# ───────────────────────────────────────────────────────────

setup_provider_credentials() {
    log "🔐 Setting up AI provider credentials..."

    local provider_to_setup
    provider_to_setup=$(echo -e "openai\nclaude" | gum choose --header "Configure credentials for which provider?")

    if [[ -z "$provider_to_setup" ]]; then
        log "No provider selected for credential setup."
        return 1
    fi

    local api_key_input
    local key_name_for_store="anthropic" # Default for Claude in store_api_key
    if [[ "$provider_to_setup" == "openai" ]]; then
        api_key_input=$(gum input --password --placeholder "OpenAI API Key (sk-...)")
        key_name_for_store="openai"
    elif [[ "$provider_to_setup" == "claude" ]]; then
        api_key_input=$(gum input --password --placeholder "Anthropic API Key (sk-ant-...)")
    else
        error "Invalid provider selected for credential setup: $provider_to_setup"
        return 1
    fi

    if [[ -n "$api_key_input" ]]; then
        # store_api_key (from ai_providers.sh) handles validation and saving
        if store_api_key "$key_name_for_store" "$api_key_input"; then
            log "✅ API key for $provider_to_setup configured successfully."
        else
            error "❌ Failed to store API key for $provider_to_setup. It might be invalid or a permission issue."
        fi
    else
        log "No API key entered for $provider_to_setup. Skipping."
    fi
}

test_provider_connection() {
    local provider_to_test="$1"
    if [[ -z "$provider_to_test" ]]; then
        provider_to_test=$(select_ai_provider) # from ai_providers.sh
        if [[ -z "$provider_to_test" ]]; then
            error "No provider selected for connection test."
            return 1
        fi
    fi

    log "🧪 Testing connection for provider: $provider_to_test..."
    if ! validate_provider_config "$provider_to_test"; then # From ai_providers.sh
        error "Configuration for $provider_to_test is invalid. Connection test aborted."
        return 1
    fi

    case "$provider_to_test" in
        ollama)
            log "Ollama server is running and CLI is available (checked by validate_provider_config)."
            log "Checking available Ollama models..."
            local ollama_models
            ollama_models=$(get_ollama_models) # from ai_providers.sh
            if [[ -n "$ollama_models" ]]; then
                log "✅ Ollama connection successful. Found models:\n$ollama_models"
                return 0
            else
                error "❌ Ollama connection test: Server running but no models found."
                return 1
            fi
            ;;
        openai)
            log "Attempting a test query to OpenAI..."
            local test_prompt="Hello"
            # Use a common, cheap model for testing that's likely to be available from OPENAI_MODELS list
            local test_model="gpt-3.5-turbo"
            # Ensure OPENAI_MODELS array is available (defined in ai_providers.sh)
            if ! printf "%s\n" "${OPENAI_MODELS[@]}" | grep -q -x "$test_model"; then
                test_model="${OPENAI_MODELS[0]}" # Fallback to the first model in the list
            fi

            local response
            response=$(query_openai "$test_model" "$test_prompt" "0.1") # query_openai is from ai_providers.sh
            if [[ $? -eq 0 && -n "$response" ]]; then
                log "✅ OpenAI connection successful. Received test response: ${response:0:50}..."
                return 0
            else
                error "❌ OpenAI connection test failed. Check API key, network, and service status."
                return 1
            fi
            ;;
        claude)
            log "Attempting a test query to Anthropic Claude..."
            local test_prompt="Hello"
            # Use a common, cheap model for testing from CLAUDE_MODELS list
            local test_model="claude-3-haiku-20240307"
            # Ensure CLAUDE_MODELS array is available (defined in ai_providers.sh)
             if ! printf "%s\n" "${CLAUDE_MODELS[@]}" | grep -q -x "$test_model"; then
                test_model="${CLAUDE_MODELS[0]}" # Fallback to the first model in the list
            fi

            local response
            response=$(query_claude "$test_model" "$test_prompt" "0.1") # query_claude is from ai_providers.sh
            if [[ $? -eq 0 && -n "$response" ]]; then
                log "✅ Claude connection successful. Received test response: ${response:0:50}..."
                return 0
            else
                error "❌ Claude connection test failed. Check API key, network, and service status."
                return 1
            fi
            ;;
        *)
            error "Unknown provider for connection test: $provider_to_test"
            return 1
            ;;
    esac
}

show_provider_status() {
    log "🔎 AI Provider Status:"
    local active_config
    # get_active_config_file is defined in main.sh. Ensure it's callable.
    # If SCRIPT_DIR/main.sh sources this file (lib/model.sh), and get_active_config_file is exported in main.sh,
    # or if this function show_provider_status is called from main.sh context, it should work.
    if command -v get_active_config_file >/dev/null 2>&1; then
        active_config=$(get_active_config_file)
    else
        # Fallback logic if get_active_config_file is not directly callable
        # This might happen if model.sh is tested or sourced in isolation.
        log "Warning: 'get_active_config_file' function not found. Trying default config paths."
        # Prioritize project-specific config if in a git repo
        local current_git_root
        current_git_root=$(get_git_repo_root 2>/dev/null) # Suppress error if not in repo
        if [[ -n "$current_git_root" && -f "$current_git_root/.git/hooks/prepare-commit-msg.properties" ]]; then
            active_config="$current_git_root/.git/hooks/prepare-commit-msg.properties"
        elif [[ -n "$INSTALL_DIR" && -f "$INSTALL_DIR/prepare-commit-msg.properties" ]]; then
            # Fallback to INSTALL_DIR (global default) if INSTALL_DIR is set
            active_config="$INSTALL_DIR/prepare-commit-msg.properties"
        else
            # Absolute last resort, may not be correct
            active_config="$HOME/.ollama-git-pitch-gen/prepare-commit-msg.properties"
        fi
    fi

    if [[ ! -f "$active_config" ]]; then
        log "Warning: Configuration file '$active_config' not found. Status will reflect defaults or direct checks."
        # Do not return; try to show status based on direct checks (e.g., API keys in env)
    else
        log "Using configuration file: $active_config"
    fi

    local primary_provider_from_config
    primary_provider_from_config=$(get_config_value "$active_config" "AI_PROVIDER" "Not Set")
    local fallback_providers_from_config
    fallback_providers_from_config=$(get_config_value "$active_config" "FALLBACK_PROVIDERS" "None")

    echo -e "\n📋 **Primary Provider:** $primary_provider_from_config"
    echo "↪️  **Fallback Providers:** $fallback_providers_from_config"
    echo "----------------------------------"

    local all_potential_providers=("ollama" "openai" "claude")
    for provider in "${all_potential_providers[@]}"; do
        local status_msg="🔸 Provider: ${provider^^}"
        local availability_msg # Renamed to avoid conflict
        local model_in_config="N/A"
        local temp_in_config="N/A"

        local validation_output
        validation_output=$(validate_provider_config "$provider" 2>&1) # from ai_providers.sh
        if [[ $? -eq 0 ]]; then
            availability_msg="✅ Configured & Available"
        else
            local error_reason
            error_reason=$(echo "$validation_output" | tail -n1 | sed 's/ERROR: //; s/.*ERROR.* //; s/Warning: //')
            availability_msg="❌ ${error_reason:-Unavailable}"
        fi

        model_in_config=$(get_config_value "$active_config" "${provider^^}_MODEL" "Not Set")
        temp_in_config=$(get_config_value "$active_config" "${provider^^}_TEMPERATURE" "Default (0.7)")

        status_msg+="\n   Status: $availability_msg"
        status_msg+="\n   Configured Model: $model_in_config"
        status_msg+="\n   Configured Temp: $temp_in_config"

        if [[ "$provider" == "$primary_provider_from_config" ]]; then
             status_msg+="\n   Role: Primary"
        elif echo "$fallback_providers_from_config" | grep -qF "$provider"; then # Use -F for fixed string matching
             status_msg+="\n   Role: Fallback"
        fi
        echo -e "$status_msg\n----------------------------------"
    done | gum format --theme=dark
}

# ───────────────────────────────────────────────────────────
# 🔹 OLLAMA-SPECIFIC FUNCTIONS (Legacy/Existing)
#    These functions are primarily for Ollama setup and management.
#    Keep them as they are if Ollama is still a supported provider.
# ───────────────────────────────────────────────────────────

create_model() { # This is Ollama specific
    local model_name_suffix="$1" # e.g., "llama3.1:latest"
    # INSTALL_DIR should be available globally, set by main.sh
    local model_file_template="${INSTALL_DIR:-$HOME/.ollama-git-pitch-gen}/Modelfile.sample"
    local temp_model_file="/tmp/pitch_modelfile_$(echo "$model_name_suffix" | tr /: _)" # Sanitize name for temp file
    local prefixed_model_name="pitch_$model_name_suffix" # e.g. pitch_llama3.1:latest

    if [[ ! -f "$model_file_template" ]]; then
        error "❌ Modelfile template '$model_file_template' not found in ${INSTALL_DIR:-$HOME/.ollama-git-pitch-gen}"
        cat > "$model_file_template" <<-EOF
# Basic Modelfile Template
# Replace <MODEL_NAME> with the base model from Ollama library (e.g., llama3:latest)
FROM <MODEL_NAME>

# System prompt (optional)
# SYSTEM You are a helpful AI assistant.

# Temperature (optional, e.g., 0.7)
# PARAMETER temperature 0.7
EOF
        log "Created a sample Modelfile template at $model_file_template. Please edit it with a valid FROM instruction."
        return 1
    fi

    if ollama list | awk '{print $1}' | grep -q -x "$prefixed_model_name"; then
        log "✅ Ollama Model '$prefixed_model_name' already exists."
        return 0
    fi

    log "📦 Creating Ollama model '$prefixed_model_name' from base '$model_name_suffix' using template..."

    # Replace placeholder in Modelfile.sample and store in a temporary file
    # The template should specify FROM <MODEL_NAME> where <MODEL_NAME> is the placeholder
    sed "s/<MODEL_NAME>/$model_name_suffix/g" "$model_file_template" > "$temp_model_file"

    log "Using generated Modelfile for $prefixed_model_name:"
    cat "$temp_model_file" # Show the temp modelfile for debugging

    if ollama create "$prefixed_model_name" -f "$temp_model_file"; then
        log "Successfully created Ollama model '$prefixed_model_name'."
        if ! check_model_exists "$prefixed_model_name"; then # Verify creation
            error "Verification failed for newly created model '$prefixed_model_name'."
            rm -f "$temp_model_file"
            return 1
        fi
    else
        error "Failed to create Ollama model '$prefixed_model_name'. Check Modelfile and Ollama server."
        log "Modelfile content was:"
        cat "$temp_model_file"
        return 1
    fi
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
    get_git_repo_root # Ensures we are in a git repo, sets $git_root
    local current_config_file="$git_root/.git/hooks/prepare-commit-msg.properties" # Project-specific config

    if [[ ! -f "$current_config_file" ]]; then
        log "Project configuration file not found at $current_config_file."
        if gum confirm "Create a default configuration file for this project?"; then
            create_default_config "$current_config_file" # from config_manager.sh
        else
            error "Cannot proceed without a configuration file."
            return 1
        fi
    fi
    
    log "🤖 Select AI Provider to configure:"
    local selected_provider
    selected_provider=$(select_ai_provider) # From ai_providers.sh
    if [[ -z "$selected_provider" ]]; then
        error "No AI provider selected. Exiting."
        return 1
    fi

    log "🎯 Select Model for $selected_provider:"
    local selected_model
    selected_model=$(select_ai_model "$selected_provider")
    if [[ -z "$selected_model" ]]; then
        error "Model selection failed for $selected_provider. Exiting."
        return 1
    fi

    # Update configuration file
    update_config_value "$current_config_file" "AI_PROVIDER" "$selected_provider"
    update_config_value "$current_config_file" "${selected_provider^^}_MODEL" "$selected_model"

    # Optionally, ask to set temperature for this provider
    if gum confirm "Set temperature for $selected_provider? (Default is usually 0.7)"; then
        local temp
        temp=$(gum input --placeholder "Enter temperature (e.g., 0.7)")
        if [[ -n "$temp" ]]; then # Add more validation for temp if needed
            update_config_value "$current_config_file" "${selected_provider^^}_TEMPERATURE" "$temp"
        fi
    fi

    log "✅ Configuration updated successfully in $current_config_file:"
    log "   Primary Provider: $selected_provider"
    log "   Model for $selected_provider: $selected_model"
    local current_temp # Read back the temperature to show it
    current_temp=$(get_config_value "$current_config_file" "${selected_provider^^}_TEMPERATURE" "not set")
    log "   Temperature for $selected_provider: $current_temp"
}

delete_models() { # Ollama specific: removes ALL local Ollama models and data.
    log "DANGER ZONE: This command will attempt to remove the Ollama models directory."
    log "This typically means all downloaded models and their data will be lost."
    local ollama_models_dir="$HOME/.ollama/models" # Common path, but can vary.
    log "The directory targeted for removal is: $ollama_models_dir"

    if [[ ! -d "$ollama_models_dir" ]]; then
        warn "Ollama models directory '$ollama_models_dir' not found. Nothing to delete."
        return
    fi

    if gum confirm "Are you absolutely sure you want to remove $ollama_models_dir and all its contents?"; then
        if rm -rf "$ollama_models_dir"; then
            log "✅ Successfully removed Ollama models directory: $ollama_models_dir."
        else
            error "❌ Failed to remove Ollama models directory: $ollama_models_dir. Check permissions."
            return 1
        fi
    else
        log "Ollama model data deletion aborted by user."
    fi
}

remove_pitch_models() { # Ollama specific: removes models with "pitch_" prefix
    log "🗑 Removing 'pitch_*' prefixed models from Ollama..."
    local pitch_models
    pitch_models=$(ollama list | awk '{print $1}' | grep "^pitch_")
    if [[ -z "$pitch_models" ]]; then
        log "No 'pitch_*' models found in Ollama to remove."
        return
    fi

    echo "The following 'pitch_*' models are available in Ollama:"
    echo "$pitch_models"
    if gum confirm "Proceed with removing ALL listed 'pitch_*' models?"; then
        for model_to_remove in $pitch_models; do
            log "Removing Ollama model: $model_to_remove..."
            if ollama rm "$model_to_remove"; then
                log "✅ Removed $model_to_remove."
            else
                error "❌ Failed to remove $model_to_remove."
            fi
        done
        log "✅ Finished removing selected 'pitch_*' Ollama models."
    else
        log "Removal of 'pitch_*' models aborted by user."
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
        # Check OS for backgrounding nohup, systemd, or launchctl
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # On macOS, 'ollama serve' often runs as a background service managed by launchd after first GUI run.
            # 'ollama run' or 'ollama ps' can start it if not running.
            # Forcing a background 'ollama serve' might conflict if a launchd service exists.
            # Let's try to start it simply, it might background itself.
            ollama serve > ~/.ollama_server.log 2>&1 &
            sleep 3 # Give it a moment to start
            if pgrep -f "ollama serve" >/dev/null; then
                 log "Ollama server started successfully."
            else
                 error "Failed to start Ollama server. Check ~/.ollama_server.log or try 'ollama serve' manually."
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Check if systemd is running
            if command -v systemctl >/dev/null && systemctl list-unit-files --type=service | grep -q "ollama.service"; then
                log "Ollama service found in systemd. Attempting to start with 'sudo systemctl start ollama'..."
                sudo systemctl start ollama || error "Failed to start Ollama service with systemctl."
            else
                 nohup ollama serve > ~/.ollama_server.log 2>&1 &
                 sleep 3
                 if pgrep -xf "ollama serve" >/dev/null; then # -x for exact match
                    log "Ollama server started successfully (using nohup)."
                 else
                    error "Failed to start Ollama server (using nohup). Check ~/.ollama_server.log or try 'ollama serve' manually."
                 fi
            fi
        else
            error "Unsupported OS for automatic Ollama server start. Please start it manually."
        fi
    fi
}

stop_ollama() {
    log "Stopping Ollama server..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # On macOS, 'ollama serve' might be managed by launchd. `pkill` might be temporary.
        # The proper way might be `launchctl stop com.ollama.ollama` if that's the service name.
        # For simplicity, pkill is used as per original script.
        if pkill -f "ollama serve"; then
            log "Ollama server stop signal sent."
        else
            warn "No running Ollama server found to stop (via pkill)."
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v systemctl >/dev/null && systemctl list-units --full -all | grep -q 'ollama.service'; then
            log "Ollama service found in systemd. Attempting to stop with 'sudo systemctl stop ollama'..."
            sudo systemctl stop ollama || error "Failed to stop Ollama service with systemctl."
        else
            if pkill -f "ollama serve"; then
                log "Ollama server stop signal sent (via pkill)."
            else
                warn "No running Ollama server found to stop (via pkill)."
            fi
        fi
    else
        warn "Unsupported OS for automatic Ollama server stop. Please stop it manually if needed."
    fi
}

install_ollama() {
    log "Checking Ollama installation..."
    if command -v ollama >/dev/null 2>&1; then
        log "✅ Ollama CLI is already installed."
        # Check if server is running, or if it's just the CLI
        if ! pgrep -xf "ollama serve" >/dev/null; then # -x for exact match
             log "Ollama CLI found, but server not running. Consider running 'pitch start' or 'ollama serve'."
        fi
        return
    fi

    log "Installing Ollama..."
    local ollama_install_script_url="https://ollama.com/install.sh"
    if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log "Downloading and running Ollama installation script from $ollama_install_script_url..."
        if curl -fsSL "$ollama_install_script_url" | sh; then
            log "Ollama installation script completed."
            # The script itself should instruct to run 'ollama serve' or similar.
            # We can try to start it here too.
            log "Attempting to start Ollama server for the first time..."
            start_ollama
        else
            error "Ollama installation script failed. Please try installing manually from https://ollama.com."
            exit 1
        fi
    else
        error "Unsupported OS for automatic Ollama installation. Please install Ollama manually from https://ollama.com."
        exit 1
    fi
}