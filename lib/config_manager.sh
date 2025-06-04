#!/bin/bash

# Script directory to source other helpers if necessary
# SCRIPT_DIR_CONFIG_MANAGER="${SCRIPT_DIR_CONFIG_MANAGER:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# source "$SCRIPT_DIR_CONFIG_MANAGER/logging.sh" # Assuming logging.sh is in the same directory or SCRIPT_DIR_CONFIG_MANAGER is set

# Ensure that the log function is available. If logging.sh is not sourced yet,
# provide a basic version or ensure it's sourced by the calling script.
if ! command -v log > /dev/null; then
    log() { echo "LOG: $*"; }
    error() { echo "ERROR: $*" >&2; }
fi


get_config_value() {
    local file="$1"
    local key="$2"
    local default_value="${3:-}" # Use provided default or empty string

    if [[ ! -f "$file" ]]; then
        echo "$default_value"
        return
    fi

    local value
    value=$(grep "^${key}=" "$file" | cut -d '=' -f2-)

    if [[ -z "$value" ]]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

update_config_value() {
    local file="$1"
    local key="$2"
    local value="$3"
    local temp_file="${file}.tmp"

    if [[ ! -f "$file" ]]; then
        # If the file doesn't exist, create it and add the key-value pair
        echo "${key}=${value}" > "$file"
        log "Created config file $file and set $key=$value"
        return
    fi

    local found=0
    # Read file line by line and write to temp file
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^${key}= ]]; then
            echo "${key}=${value}" >> "$temp_file"
            found=1
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$file"

    # If key was not found, append it to the temp file
    if [[ "$found" -eq 0 ]]; then
        echo "${key}=${value}" >> "$temp_file"
    fi

    # Replace original file with temp file
    mv "$temp_file" "$file"
    log "Updated $key to $value in $file"
}

create_default_config() {
    local file="$1"
    if [[ -f "$file" ]]; then
        log "Config file $file already exists. Skipping creation of default config."
        return
    fi

    log "Creating default config file: $file"
    # Create the directory if it doesn't exist (e.g. .git/hooks)
    mkdir -p "$(dirname "$file")"

    cat > "$file" <<EOF
# =============================================================
# Multi-AI Provider Configuration for Git Pitch Generator
# =============================================================

# Primary AI Provider (ollama, openai, claude)
AI_PROVIDER=ollama

# Fallback Providers (comma-separated, tried in order if primary fails)
FALLBACK_PROVIDERS=openai,claude

# =============================================================
# Model Configuration (per provider)
# =============================================================
OLLAMA_MODEL=pitch_llama3.1:latest
OPENAI_MODEL=gpt-4o-mini
CLAUDE_MODEL=claude-3-5-sonnet-20240620 # Updated to a valid model from issue spec

# =============================================================
# Temperature Settings (creativity level: 0.0-1.0)
# =============================================================
OLLAMA_TEMPERATURE=0.7
OPENAI_TEMPERATURE=0.7
CLAUDE_TEMPERATURE=0.7

# =============================================================
# API Configuration (optional - prefer environment variables)
# =============================================================
# OPENAI_API_KEY_FILE=~/.openai/api_key
# ANTHROPIC_API_KEY_FILE=~/.anthropic/api_key

# =============================================================
# Legacy Settings (for backward compatibility)
# =============================================================
UNIFIED_LINES=50
ALLOW_COMMIT_OVERRIDE=true
OLLAMA_PROMPT=""
MAX_DIFF_LINES=500
EOF
    log "Default config written to $file"
}

migrate_legacy_config() {
    local file="$1"
    log "Checking legacy config file: $file"

    if [[ ! -f "$file" ]]; then
        log "No legacy config file found at $file to migrate."
        create_default_config "$file" # Create a new default if old one doesn't exist
        return
    fi

    # Check if AI_PROVIDER key already exists. If so, assume it's a new config.
    if grep -q "^AI_PROVIDER=" "$file"; then
        log "File $file seems to be already using the new multi-provider format. No migration needed."
        return
    fi

    log "Migrating legacy config file: $file"
    local temp_migrated_file="${file}.migrated.tmp"

    # Get existing OLLAMA_MODEL and OLLAMA_PROMPT if they exist
    local ollama_model
    ollama_model=$(get_config_value "$file" "OLLAMA_MODEL" "pitch_llama3.1:latest")
    # Legacy OLLAMA_PROMPT is not directly used in the new structure's AI calls,
    # but we can preserve it if other parts of the script still use it.
    # The new system uses prompts directly in functions like commit(), ask().

    # Preserve other existing settings
    local unified_lines
    unified_lines=$(get_config_value "$file" "UNIFIED_LINES" "50")
    local allow_commit_override
    allow_commit_override=$(get_config_value "$file" "ALLOW_COMMIT_OVERRIDE" "true")
    local max_diff_lines
    max_diff_lines=$(get_config_value "$file" "MAX_DIFF_LINES" "500")
    local legacy_ollama_prompt # Keep this if it was used
    legacy_ollama_prompt=$(get_config_value "$file" "OLLAMA_PROMPT" "")


    # Create the new config content
    cat > "$temp_migrated_file" <<EOF
# =============================================================
# Multi-AI Provider Configuration for Git Pitch Generator
# (Migrated from legacy configuration)
# =============================================================

# Primary AI Provider (ollama, openai, claude)
AI_PROVIDER=ollama # Default to ollama for legacy users

# Fallback Providers (comma-separated, tried in order if primary fails)
FALLBACK_PROVIDERS=openai,claude # Default fallbacks

# =============================================================
# Model Configuration (per provider)
# =============================================================
OLLAMA_MODEL=${ollama_model} # Preserved from old config
OPENAI_MODEL=gpt-4o-mini # Default OpenAI model
CLAUDE_MODEL=claude-3-5-sonnet-20240620 # Default Claude model

# =============================================================
# Temperature Settings (creativity level: 0.0-1.0)
# =============================================================
OLLAMA_TEMPERATURE=0.7 # Default temperature
OPENAI_TEMPERATURE=0.7
CLAUDE_TEMPERATURE=0.7

# =============================================================
# API Configuration (optional - prefer environment variables)
# =============================================================
# OPENAI_API_KEY_FILE=~/.openai/api_key
# ANTHROPIC_API_KEY_FILE=~/.anthropic/api_key

# =============================================================
# Legacy Settings (for backward compatibility)
# =============================================================
UNIFIED_LINES=${unified_lines}
ALLOW_COMMIT_OVERRIDE=${allow_commit_override}
OLLAMA_PROMPT=${legacy_ollama_prompt} # Preserved legacy prompt
MAX_DIFF_LINES=${max_diff_lines}
EOF

    mv "$temp_migrated_file" "$file"
    log "Legacy config $file migrated to new format."
}

validate_full_config() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        error "Config file $file not found for validation."
        return 1
    fi

    local required_keys=(
        "AI_PROVIDER"
        "OLLAMA_MODEL"
        "OPENAI_MODEL"
        "CLAUDE_MODEL"
    )
    local all_keys_present=true
    for key in "${required_keys[@]}"; do
        if ! grep -q "^${key}=" "$file"; then
            error "Missing required configuration key: $key in $file"
            all_keys_present=false
        fi
    done

    if ! $all_keys_present; then
        error "Configuration file $file is invalid. Please check missing keys."
        return 1
    fi

    # Validate AI_PROVIDER value
    local ai_provider
    ai_provider=$(get_config_value "$file" "AI_PROVIDER")
    if [[ "$ai_provider" != "ollama" && "$ai_provider" != "openai" && "$ai_provider" != "claude" ]]; then
        error "Invalid AI_PROVIDER value: '$ai_provider'. Must be 'ollama', 'openai', or 'claude'."
        return 1
    fi

    # TODO: Add more specific validation for model names against known lists if necessary,
    # or ensure that `validate_model_for_provider` is called appropriately before use.
    # For now, presence of the model key is the main check here.

    log "Configuration file $file appears valid."
    return 0
}
