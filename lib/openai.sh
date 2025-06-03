#!/bin/bash

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

    # echo "Payload: $json_payload"

    # Make API call
    # -s for silent, -w to write out http_code, timeout for safety
    response_data=$(curl --connect-timeout 15 --max-time 60 -s -w "\n%{http_code}" https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    http_code=$(echo "$response_data" | tail -n1)
    response_body=$(echo "$response_data" | sed '$d')

    echo "Response: $response_body"

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
