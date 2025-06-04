#!/bin/bash

# Script directory to source other helpers
SCRIPT_DIR_AI_PROVIDERS="${SCRIPT_DIR_AI_PROVIDERS:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$SCRIPT_DIR_AI_PROVIDERS/logging.sh" # Assuming logging.sh is in the same directory or SCRIPT_DIR_AI_PROVIDERS is set
source "$SCRIPT_DIR_AI_PROVIDERS/config_manager.sh" # Assuming config_manager.sh is in the same directory

# -----------------------------------------------------------------------------
# Provider Detection and Selection
# -----------------------------------------------------------------------------

# OpenAI Models
OPENAI_MODELS=("gpt-4o" "gpt-4o-mini" "gpt-4-turbo" "gpt-3.5-turbo")

# Claude Models
CLAUDE_MODELS=("claude-3-5-sonnet-20240620" "claude-3-opus-20240229" "claude-3-sonnet-20240229" "claude-3-haiku-20240307")


get_openai_api_key() {
    local key_file
    key_file=$(get_config_value "$CONFIG_FILE" "OPENAI_API_KEY_FILE" "~/.openai/api_key")
    key_file=$(eval echo "$key_file") # Expand tilde

    if [[ -n "$OPENAI_API_KEY" ]]; then
        echo "$OPENAI_API_KEY"
    elif [[ -f "$key_file" ]]; then
        cat "$key_file"
    else
        echo ""
    fi
}

get_claude_api_key() {
    local key_file
    key_file=$(get_config_value "$CONFIG_FILE" "ANTHROPIC_API_KEY_FILE" "~/.anthropic/api_key")
    key_file=$(eval echo "$key_file") # Expand tilde

    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        echo "$ANTHROPIC_API_KEY"
    elif [[ -f "$key_file" ]]; then
        cat "$key_file"
    else
        echo ""
    fi
}

validate_api_key() {
    local provider="$1"
    local key="$2"
    # Basic validation: OpenAI keys start with "sk-", Claude keys with "sk-ant-"
    # More specific validation can be added if needed.
    if [[ "$provider" == "openai" && "$key" == sk-* ]]; then
        return 0
    elif [[ "$provider" == "claude" && "$key" == sk-ant-* ]]; then
        return 0
    fi
    log "Warning: Invalid API key format for $provider."
    return 1
}

store_api_key() {
    local provider="$1"
    local key="$2"
    local key_file_config_key
    local key_dir

    if [[ "$provider" == "openai" ]]; then
        key_file_config_key="OPENAI_API_KEY_FILE"
        key_dir="$HOME/.openai"
    elif [[ "$provider" == "anthropic" ]]; then # Ensure this matches the key used in get_claude_api_key
        key_file_config_key="ANTHROPIC_API_KEY_FILE"
        key_dir="$HOME/.anthropic"
    else
        error "Unsupported provider for API key storage: $provider"
        return 1
    fi

    local key_file_path="$key_dir/api_key"

    if ! validate_api_key "$provider" "$key"; then
        error "Invalid API key format for $provider. Key not stored."
        return 1
    fi

    mkdir -p "$key_dir"
    echo "$key" > "$key_file_path"
    chmod 600 "$key_file_path"

    # Update config to point to this new file if the user chose file storage
    # This assumes CONFIG_FILE is globally available and points to the correct project config
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        update_config_value "$CONFIG_FILE" "$key_file_config_key" "$key_file_path"
        log "API key for $provider stored in $key_file_path and configuration updated."
    else
        log "API key for $provider stored in $key_file_path. Configuration file not found or specified."
    fi
}


get_available_providers() {
    local available=()
    # Check Ollama
    if command -v ollama >/dev/null 2>&1 && pgrep -f "ollama serve" >/dev/null; then
        available+=("ollama")
    fi
    # Check OpenAI
    if [[ -n "$(get_openai_api_key)" ]]; then
        available+=("openai")
    fi
    # Check Claude
    if [[ -n "$(get_claude_api_key)" ]]; then
        available+=("claude")
    fi
    echo "${available[@]}"
}

select_ai_provider() {
    local providers
    providers=$(get_available_providers)
    if [[ -z "$providers" ]]; then
        error "No AI providers available or configured."
        return 1
    fi
    # Convert space-separated string to lines for gum
    echo "$providers" | tr ' ' '\n' | gum choose --header "Select AI Provider:"
}

validate_provider_config() {
    local provider="$1"
    case "$provider" in
        ollama)
            if ! command -v ollama >/dev/null 2>&1; then
                error "Ollama CLI not found."
                return 1
            fi
            if ! pgrep -f "ollama serve" >/dev/null; then
                error "Ollama server is not running."
                return 1
            fi
            ;;
        openai)
            if [[ -z "$(get_openai_api_key)" ]]; then
                error "OpenAI API key not found. Set OPENAI_API_KEY or configure OPENAI_API_KEY_FILE."
                return 1
            fi
            ;;
        claude)
            if [[ -z "$(get_claude_api_key)" ]]; then
                error "Anthropic API key not found. Set ANTHROPIC_API_KEY or configure ANTHROPIC_API_KEY_FILE."
                return 1
            fi
            ;;
        *)
            error "Unknown provider: $provider"
            return 1
            ;;
    esac
    return 0
}

# -----------------------------------------------------------------------------
# Model Management per Provider
# -----------------------------------------------------------------------------

get_ollama_models() {
    if command -v ollama >/dev/null 2>&1; then
        ollama list | awk '{print $1}' | tail -n +2
    else
        echo ""
    fi
}

get_openai_models() {
    printf "%s\n" "${OPENAI_MODELS[@]}"
}

get_claude_models() {
    printf "%s\n" "${CLAUDE_MODELS[@]}"
}

get_models_for_provider() {
    local provider="$1"
    case "$provider" in
        ollama) get_ollama_models ;;
        openai) get_openai_models ;;
        claude) get_claude_models ;;
        *) error "Unknown provider: $provider"; return 1 ;;
    esac
}

validate_model_for_provider() {
    local provider="$1"
    local model_name="$2"
    local models_list
    models_list=$(get_models_for_provider "$provider")

    if echo "$models_list" | grep -q -x "$model_name"; then
        return 0 # Model is valid
    else
        error "Model '$model_name' is not valid or available for provider '$provider'."
        return 1 # Model is not valid
    fi
}


# -----------------------------------------------------------------------------
# Provider-specific Query Implementations
# -----------------------------------------------------------------------------

query_ollama() {
    local model="$1"
    local prompt="$2"
    local temperature="${3:-0.7}" # Default temperature if not provided

    if ! validate_provider_config "ollama"; then return 1; fi
    if ! validate_model_for_provider "ollama" "$model"; then return 1; fi

    # Ollama API expects temperature as a parameter in the JSON body
    # The 'ollama run' CLI does not directly support temperature.
    # This might need adjustment if direct API calls are preferred over 'ollama run'.
    # For now, sticking to 'ollama run' as per existing structure.
    # Temperature control for 'ollama run' would typically be part of the Modelfile or a global setting.
    # The `ollama run` command itself doesn't take a temperature argument.
    # We will assume the model's Modelfile has temperature set, or use `ollama generate` API endpoint.
    # For simplicity, let's use `ollama run` and ignore temperature for now for Ollama CLI.

    response=$(ollama run "$model" "$prompt")
    if [[ $? -ne 0 ]]; then
        error "Ollama query failed."
        return 1
    fi
    echo "$response"
}

query_openai() {
    local model="$1"
    local prompt="$2"
    local temperature="${3:-0.7}"
    local api_key
    api_key=$(get_openai_api_key)

    if ! validate_provider_config "openai"; then return 1; fi
    if ! validate_model_for_provider "openai" "$model"; then return 1; fi

    local retries=3
    local backoff=1
    local response
    local http_status

    for ((i=0; i<retries; i++)); do
        response=$(curl -s -w "\n%{http_code}" -X POST "https://api.openai.com/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $api_key" \
            -d "$(jq -n --arg model "$model" --arg prompt "$prompt" --argjson temp "$temperature" \
                '{model: $model, messages: [{role: "user", content: $prompt}], temperature: $temp}')")

        http_status=$(echo "$response" | tail -n1)
        response_body=$(echo "$response" | sed '$d')

        if [[ "$http_status" -eq 200 ]]; then
            echo "$response_body" | jq -r '.choices[0].message.content'
            return 0
        elif [[ "$http_status" -eq 429 || "$http_status" -ge 500 ]]; then # Rate limit or server error
            log "OpenAI API returned HTTP $http_status. Retrying in $backoff seconds..."
            sleep "$backoff"
            backoff=$((backoff * 2))
        else
            error "OpenAI API Error (HTTP $http_status): $(echo "$response_body" | jq -r '.error.message // .')"
            return 1
        fi
    done

    error "OpenAI API query failed after $retries retries."
    return 1
}

query_claude() {
    local model="$1"
    local prompt="$2"
    local temperature="${3:-0.7}"
    local api_key
    api_key=$(get_claude_api_key)

    if ! validate_provider_config "claude"; then return 1; fi
    if ! validate_model_for_provider "claude" "$model"; then return 1; fi

    local retries=3
    local backoff=1
    local response
    local http_status

    for ((i=0; i<retries; i++)); do
        response=$(curl -s -w "\n%{http_code}" -X POST "https://api.anthropic.com/v1/messages" \
            -H "x-api-key: $api_key" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d "$(jq -n --arg model "$model" --arg prompt "$prompt" --argjson temp "$temperature" \
                '{model: $model, max_tokens: 4096, messages: [{role: "user", content: $prompt}], temperature: $temp}')")

        http_status=$(echo "$response" | tail -n1)
        response_body=$(echo "$response" | sed '$d')

        if [[ "$http_status" -eq 200 ]]; then
            echo "$response_body" | jq -r '.content[0].text'
            return 0
        elif [[ "$http_status" -eq 429 || "$http_status" -ge 500 ]]; then # Rate limit or server error
            log "Claude API returned HTTP $http_status. Retrying in $backoff seconds..."
            sleep "$backoff"
            backoff=$((backoff * 2))
        else
            error "Claude API Error (HTTP $http_status): $(echo "$response_body" | jq -r '.error.message // .')"
            return 1
        fi
    done

    error "Claude API query failed after $retries retries."
    return 1
}

# -----------------------------------------------------------------------------
# Universal AI Interface
# -----------------------------------------------------------------------------

query_ai() {
    local provider="$1"
    local model="$2"
    local prompt="$3"
    local temperature="${4}" # Will be handled by individual query functions with their defaults

    log "Querying AI provider: $provider, Model: $model"

    # Validate provider configuration first
    if ! validate_provider_config "$provider"; then
        error "Validation failed for provider $provider."
        return 1
    fi

    # Validate model for the provider
    if ! validate_model_for_provider "$provider" "$model"; then
        error "Validation failed for model $model on provider $provider."
        return 1
    fi

    local result
    case "$provider" in
        ollama) result=$(query_ollama "$model" "$prompt" "$temperature") ;;
        openai) result=$(query_openai "$model" "$prompt" "$temperature") ;;
        claude) result=$(query_claude "$model" "$prompt" "$temperature") ;;
        *)
            error "Unsupported AI provider: $provider"
            return 1
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        error "AI query failed for provider $provider with model $model."
        return 1
    fi
    echo "$result"
}

query_ai_with_fallback() {
    # CONFIG_FILE needs to be accessible, ensure it's exported or sourced correctly
    # from where this function is called, or pass it as an argument.
    # For now, assume CONFIG_FILE is a global variable pointing to the project's config.
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE. Cannot determine provider order."
        # As a last resort, try ollama if available and no config
        if command -v ollama >/dev/null 2>&1 && pgrep -f "ollama serve" >/dev/null; then
             log "No config, attempting Ollama with a default model."
             local default_ollama_model=$(get_ollama_models | head -n1)
             if [[ -n "$default_ollama_model" ]]; then
                 query_ai "ollama" "$default_ollama_model" "$2" "$3" # $1 is primary_provider, $2 prompt, $3 temp
                 return $?
             else
                 error "No Ollama models found for default attempt."
                 return 1
             fi
        fi
        return 1
    fi

    local primary_provider
    primary_provider=$(get_config_value "$CONFIG_FILE" "AI_PROVIDER" "ollama")

    local model_key_suffix="${primary_provider^^}_MODEL" # e.g. OLLAMA_MODEL, OPENAI_MODEL
    local temp_key_suffix="${primary_provider^^}_TEMPERATURE" # e.g. OLLAMA_TEMPERATURE

    local model
    model=$(get_config_value "$CONFIG_FILE" "$model_key_suffix")
    local temperature
    temperature=$(get_config_value "$CONFIG_FILE" "$temp_key_suffix" "0.7")

    local prompt="$1" # The first argument to this function is the prompt

    log "Attempting primary provider: $primary_provider with model $model"
    local result
    result=$(query_ai "$primary_provider" "$model" "$prompt" "$temperature")
    if [[ $? -eq 0 && -n "$result" ]]; then
        echo "$result"
        return 0
    fi
    log "Primary provider $primary_provider failed or returned empty result."

    local fallback_providers_str
    fallback_providers_str=$(get_config_value "$CONFIG_FILE" "FALLBACK_PROVIDERS" "")

    IFS=',' read -ra fallbacks <<< "$fallback_providers_str"
    for provider_fb in "${fallbacks[@]}"; do
        log "Attempting fallback provider: $provider_fb"
        local fb_model_key_suffix="${provider_fb^^}_MODEL"
        local fb_temp_key_suffix="${provider_fb^^}_TEMPERATURE"

        local fb_model
        fb_model=$(get_config_value "$CONFIG_FILE" "$fb_model_key_suffix")
        local fb_temperature
        fb_temperature=$(get_config_value "$CONFIG_FILE" "$fb_temp_key_suffix" "0.7")

        if [[ -z "$fb_model" ]]; then
            log "No model configured for fallback provider $provider_fb. Skipping."
            continue
        fi

        result=$(query_ai "$provider_fb" "$fb_model" "$prompt" "$fb_temperature")
        if [[ $? -eq 0 && -n "$result" ]]; then
            log "Fallback provider $provider_fb succeeded."
            echo "$result"
            return 0
        fi
        log "Fallback provider $provider_fb failed or returned empty result."
    done

    error "All AI providers failed."
    return 1
}
