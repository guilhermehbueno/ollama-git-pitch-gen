#!/bin/bash

# Ensure lib/utils.sh and lib/git.sh are sourced if their functions are needed
# SCRIPT_DIR="$HOME/.ollama-git-pitch-gen" # Or determine dynamically
# source "$SCRIPT_DIR/lib/utils.sh" # For log_error or other utils if you add them
# source "$SCRIPT_DIR/lib/git.sh" # For get_git_repo_root

call_openai_api() {
    local prompt_content="$1"
    local openai_model_name="$2"
    local git_root
    local config_file
    local api_key

    # Get Git root and config file path
    # Assuming get_git_repo_root is available from a sourced lib/git.sh
    if ! command -v get_git_repo_root &> /dev/null; then
        echo "Error: get_git_repo_root function not found. Ensure lib/git.sh is sourced." >&2
        return 1
    fi
    git_root=$(get_git_repo_root)
    if [[ -z "$git_root" ]]; then
        echo "Error: Not inside a Git repository." >&2
        return 1
    fi
    config_file="$git_root/.git/hooks/prepare-commit-msg.properties"

    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file '$config_file' not found." >&2
        return 1
    fi

    # Read API Key
    api_key=$(grep "^OPENAI_API_KEY=" "$config_file" | cut -d '=' -f2-)
    if [[ -z "$api_key" ]]; then
        echo "Error: OPENAI_API_KEY not found or not set in $config_file." >&2
        echo "Please run 'pitch model' to configure an OpenAI model and API key." >&2
        return 1
    fi

    # Construct JSON payload
    # Basic escaping for JSON: escape double quotes and newlines
    escaped_prompt_content=$(echo "$prompt_content" | sed -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')

    json_payload=$(printf '{
        "model": "%s",
        "messages": [{"role": "user", "content": "%s"}]
    }' "$openai_model_name" "$escaped_prompt_content")

    # Make API call
    # -s for silent, -w to write out http_code, timeout for safety
    response_data=$(curl --connect-timeout 15 --max-time 60 -s -w "\n%{http_code}" https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    http_code=$(echo "$response_data" | tail -n1)
    response_body=$(echo "$response_data" | sed '$d')

    if [[ "$http_code" -ne 200 ]]; then
        echo "Error: OpenAI API request failed with status code $http_code." >&2
        # Try to parse error message from response if available
        error_message=$(echo "$response_body" | jq -r '.error.message' 2>/dev/null)
        if [[ -n "$error_message" && "$error_message" != "null" ]]; then
            echo "API Error: $error_message" >&2
        else
            echo "Response: $response_body" >&2
        fi
        return 1
    fi

    # Parse response (jq is preferred)
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install jq to process OpenAI responses." >&2
        echo "You can usually install it with: sudo apt-get install jq (Debian/Ubuntu), sudo yum install jq (Fedora), brew install jq (macOS)" >&2
        return 1
    fi
    
    assistant_response=$(echo "$response_body" | jq -r '.choices[0].message.content')

    if [[ -z "$assistant_response" || "$assistant_response" == "null" ]]; then
        echo "Error: Could not extract assistant's response from OpenAI API output." >&2
        echo "Response body: $response_body" >&2
        # Log the full response body for debugging if extraction fails
        return 1
    fi

    echo "$assistant_response"
}

# Example usage (for testing purposes, comment out or remove in production):
# test_openai_call() {
#   echo "Testing OpenAI API call..."
#   # Ensure you have a .git/hooks/prepare-commit-msg.properties with OPENAI_API_KEY set
#   # And that get_git_repo_root is available.
#   # This requires lib/git.sh to be in the same directory or sourced.
#   # If lib/git.sh is in ../lib relative to this script:
#   # source "$(dirname "$0")/../lib/git.sh" # Adjust path as necessary
#
#   local test_prompt="Translate 'hello world' to French."
#   local test_model="gpt-3.5-turbo" # Or any other model you have access to
#   
#   echo "Prompt: $test_prompt"
#   echo "Model: $test_model"
#   
#   # Create a dummy properties file for testing if needed
#   # local git_root_test=$(get_git_repo_root)
#   # local config_file_test="$git_root_test/.git/hooks/prepare-commit-msg.properties"
#   # if [ ! -f "$config_file_test" ]; then
#   #   mkdir -p "$(dirname "$config_file_test")"
#   #   echo "OPENAI_API_KEY=your_dummy_or_real_key_for_testing" > "$config_file_test"
#   #   echo "OLLAMA_MODEL=openai/$test_model" >> "$config_file_test"
#   # fi
#
#   response=$(call_openai_api "$test_prompt" "$test_model")
#   exit_code=$?
#
#   if [[ $exit_code -eq 0 ]]; then
#       echo "OpenAI Response: $response"
#   else
#       echo "OpenAI API call failed with exit code $exit_code."
#       # The error message would have been printed by call_openai_api itself.
#   fi
# }
#
# If you want to run the test:
# Ensure lib/git.sh is available. You might need to adjust the source line in test_openai_call or source it before calling.
# For example, if lib/git.sh is one directory up:
# if [ -f "$(dirname "$0")/../lib/git.sh" ]; then
#    source "$(dirname "$0")/../lib/git.sh"
#    test_openai_call
# else
#    echo "lib/git.sh not found, skipping test_openai_call"
# fi
