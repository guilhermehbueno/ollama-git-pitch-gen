#!/bin/bash

# Basic Test Framework (TAP-like output)
# Run this script from the project root or ensure SCRIPT_DIR is set appropriately.

# Determine project root directory, assuming tests are in project_root/tests/
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Source necessary scripts from the lib directory
export SCRIPT_DIR="$PROJECT_ROOT" # Used by sourced scripts to find other libs
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/config_manager.sh"
source "$PROJECT_ROOT/lib/ai_providers.sh"

# Silence regular log messages during tests, only show errors or test output
DISABLE_LOGS="true"

# Test counter
TEST_NUM=0
PASSED_TESTS=0
FAILED_TESTS=0

# Mock an active config file for tests
MOCK_CONFIG_FILE="$TEST_DIR/mock_config.properties"
export CONFIG_FILE="$MOCK_CONFIG_FILE" # Make it available to sourced functions

# Helper to run a test
# Usage: run_test "description of test" command_to_run_test
run_test() {
    ((TEST_NUM++))
    local description="$1"
    shift
    local command_to_run="$@"

    echo -n "Test $TEST_NUM: $description ... "

    # Execute command and capture output and status
    local output
    local status
    output=$(eval "$command_to_run" 2>&1) # Capture stdout and stderr
    status=$?

    if [ $status -eq 0 ]; then
        echo "ok"
        ((PASSED_TESTS++))
    else
        echo "not ok"
        echo "  ---"
        echo "  Status: $status"
        echo "  Output:"
        echo "$output" | sed 's/^/    /' # Indent output
        echo "  ..."
        ((FAILED_TESTS++))
    fi
}

# Function to assert truth (exit status 0)
assert_true() {
    "$@"
}

# Function to assert success (command returns 0)
assert_success() {
    "$@"
}

# Function to assert failure (command returns non-0)
assert_failure() {
    if "$@"; then return 1; else return 0; fi
}

# Function to assert output contains substring
# Usage: assert_output_contains "command" "expected_substring"
assert_output_contains() {
    local cmd="$1"
    local expected_substring="$2"
    local output
    output=$(eval "$cmd")
    if echo "$output" | grep -qF "$expected_substring"; then
        return 0
    else
        echo "Assertion failed: Output of '$cmd' did not contain '$expected_substring'. Output was:" >&2
        echo "$output" >&2
        return 1
    fi
}

# Function to assert output equals string
# Usage: assert_output_equals "command" "expected_string"
assert_output_equals() {
    local cmd="$1"
    local expected_string="$2"
    local output
    output=$(eval "$cmd")
    if [[ "$output" == "$expected_string" ]]; then
        return 0
    else
        echo "Assertion failed: Output of '$cmd' was '$output', expected '$expected_string'." >&2
        return 1
    fi
}

# --- Test Setup ---
setup_mock_environment() {
    echo "Setting up mock environment..."
    # Create a default mock config file
    create_default_config "$MOCK_CONFIG_FILE"
    # Mock Ollama server running
    # To mock 'pgrep -f "ollama serve"' returning true (pid found)
    # we can define pgrep as a function for the test script's scope
    # Or, rely on actual ollama status for some tests, and mock for others.
    # For now, assume ollama might be running or not. Tests should handle both.
}

cleanup_mock_environment() {
    echo "Cleaning up mock environment..."
    rm -f "$MOCK_CONFIG_FILE"
    unset pgrep # Remove mock pgrep if defined
    # Unset mocked API keys
    unset OPENAI_API_KEY
    unset ANTHROPIC_API_KEY
    rm -rf "$HOME/.openai/api_key_test_ai_providers" # Clean up test key files
    rm -rf "$HOME/.anthropic/api_key_test_ai_providers"
}

# --- Test Cases ---

test_api_key_validation() {
    run_test "Validate correct OpenAI API key format" assert_success validate_api_key "openai" "sk-1234567890abcdef1234567890abcdef12345678"
    run_test "Validate incorrect OpenAI API key format (too short)" assert_failure validate_api_key "openai" "sk-123"
    run_test "Validate incorrect OpenAI API key format (wrong prefix)" assert_failure validate_api_key "openai" "pk-1234567890abcdef"

    run_test "Validate correct Claude API key format" assert_success validate_api_key "claude" "sk-ant-api03-123456-abcdef-ABABAB_ababab-123456"
    run_test "Validate incorrect Claude API key format (wrong prefix)" assert_failure validate_api_key "claude" "sk-123456"
}

test_api_key_retrieval_and_storage() {
    # Test storing and retrieving OpenAI key
    local test_openai_key="sk-testopenaikey12345"
    local openai_key_file_path_test="$HOME/.openai/api_key_test_ai_providers"
    mkdir -p "$(dirname "$openai_key_file_path_test")"
    update_config_value "$MOCK_CONFIG_FILE" "OPENAI_API_KEY_FILE" "$openai_key_file_path_test"

    run_test "Store valid OpenAI API key" assert_success store_api_key "openai" "$test_openai_key"
    run_test "Retrieve stored OpenAI API key from file" assert_output_equals "get_openai_api_key" "$test_openai_key"
    run_test "File permissions for OpenAI key should be 600" assert_true test -f "$openai_key_file_path_test" "&&" test "\$(stat -c %a '$openai_key_file_path_test')" = "600"

    # Test storing and retrieving Claude key
    local test_claude_key="sk-ant-testclaudekey67890"
    local claude_key_file_path_test="$HOME/.anthropic/api_key_test_ai_providers"
    mkdir -p "$(dirname "$claude_key_file_path_test")"
    update_config_value "$MOCK_CONFIG_FILE" "ANTHROPIC_API_KEY_FILE" "$claude_key_file_path_test"

    run_test "Store valid Claude API key" assert_success store_api_key "anthropic" "$test_claude_key"
    run_test "Retrieve stored Claude API key from file" assert_output_equals "get_claude_api_key" "$test_claude_key"
    run_test "File permissions for Claude key should be 600" assert_true test -f "$claude_key_file_path_test" "&&" test "\$(stat -c %a '$claude_key_file_path_test')" = "600"

    # Test retrieval via environment variables
    export OPENAI_API_KEY="sk-envopenaikey"
    run_test "Retrieve OpenAI API key from ENV var" assert_output_equals "get_openai_api_key" "sk-envopenaikey"
    unset OPENAI_API_KEY

    export ANTHROPIC_API_KEY="sk-ant-envclaudekey"
    run_test "Retrieve Claude API key from ENV var" assert_output_equals "get_claude_api_key" "sk-ant-envclaudekey"
    unset ANTHROPIC_API_KEY
}

test_provider_detection() {
    # Mock pgrep for Ollama detection for isolated testing
    # This will only affect calls to pgrep within this script's execution of sourced functions
    pgrep() {
        if [[ "$*" == *-f*"ollama serve"* ]]; then
            echo "12345" # Simulate PID found
            return 0
        else
            command pgrep "$@" # Call actual pgrep for other cases
        fi
    }
    export -f pgrep # Make the function available to subshells (like command substitution)

    # Scenario 1: Ollama running, no API keys
    run_test "Detect only Ollama available" assert_output_contains 'get_available_providers' "ollama"
    run_test "Detect only Ollama available (exact match)" assert_output_equals 'get_available_providers' "ollama"


    # Scenario 2: Ollama running, OpenAI key set via ENV
    export OPENAI_API_KEY="sk-envopenaikey123"
    run_test "Detect Ollama and OpenAI (OpenAI key in ENV)" assert_output_contains 'get_available_providers' "ollama openai"

    # Scenario 3: Ollama running, OpenAI key in file, Claude key in ENV
    echo "sk-fileopenaikey456" > "$HOME/.openai/api_key_test_ai_providers"
    update_config_value "$MOCK_CONFIG_FILE" "OPENAI_API_KEY_FILE" "$HOME/.openai/api_key_test_ai_providers"
    unset OPENAI_API_KEY # Remove ENV var to test file preference
    export ANTHROPIC_API_KEY="sk-ant-envclaudekey789"
    run_test "Detect Ollama, OpenAI (file), Claude (ENV)" assert_output_contains 'get_available_providers' "ollama openai claude"

    # Cleanup for this test section
    unset OPENAI_API_KEY
    unset ANTHROPIC_API_KEY
    rm -f "$HOME/.openai/api_key_test_ai_providers"
    unset pgrep # Remove mock pgrep
}

test_model_lists_and_validation() {
    run_test "Get OpenAI models list (not empty)" "test -n \"\$(get_openai_models)\""
    run_test "Validate a correct OpenAI model" assert_success validate_model_for_provider "openai" "gpt-4o"
    run_test "Validate an incorrect OpenAI model" assert_failure validate_model_for_provider "openai" "gpt-invalid"

    run_test "Get Claude models list (not empty)" "test -n \"\$(get_claude_models)\""
    run_test "Validate a correct Claude model" assert_success validate_model_for_provider "claude" "claude-3-opus-20240229"
    run_test "Validate an incorrect Claude model" assert_failure validate_model_for_provider "claude" "claude-invalid"

    # Ollama model validation depends on `ollama list` output, harder to mock here without deeper changes
    # These will be more integration-style tests if run against a live Ollama instance.
    # For now, assume get_ollama_models works if ollama command is present.
    if command -v ollama >/dev/null 2>&1; then
        log "INFO: Running Ollama model tests (requires Ollama CLI and potentially running server with models)"
        # Create a dummy model for testing if possible, or ensure one exists.
        # This part is more of an integration test.
        # For a unit test, `ollama` command itself would need to be mocked.
        # run_test "Get Ollama models list (if ollama present)" "test -n "\$(get_ollama_models)""
        # run_test "Validate an existing Ollama model (e.g., pitch_llama3.1:latest - requires it to exist)" assert_success validate_model_for_provider "ollama" "pitch_llama3.1:latest"
        # run_test "Validate a non-existent Ollama model" assert_failure validate_model_for_provider "ollama" "nonexistent-ollama-model"
    else
        log "WARN: Ollama CLI not found, skipping Ollama model validation tests."
    fi
}


test_query_ai_functions_mocked() {
    # Mock curl and jq for testing API call structure without real calls
    # This is a simplified mock, a real mock server (next step) is better.

    # Mock for OpenAI
    mock_curl_openai() {
        echo "Mock curl for OpenAI called with: $*" >&2 # Log call to stderr for test visibility
        # Simulate a successful response structure
        if [[ "$*" == *api.openai.com* ]]; then
            echo '{
                "choices": [
                    {
                        "message": {
                            "role": "assistant",
                            "content": "Mocked OpenAI response"
                        }
                    }
                ]
            }'
            echo "200" # HTTP status code on a new line
            return 0
        fi
        return 1 # Should not happen if test is specific
    }

    # Mock for Claude
    mock_curl_claude() {
        echo "Mock curl for Claude called with: $*" >&2
        if [[ "$*" == *api.anthropic.com* ]]; then
            echo '{
                "content": [
                    {
                        "type": "text",
                        "text": "Mocked Claude response"
                    }
                ]
            }'
            echo "200"
            return 0
        fi
        return 1
    }

    # Test OpenAI query (mocked)
    export OPENAI_API_KEY="sk-mockapikey"
    update_config_value "$MOCK_CONFIG_FILE" "OPENAI_MODEL" "gpt-4o"
    # Temporarily replace curl with our mock
    local original_curl_path
    original_curl_path=$(command -v curl)
    curl() { mock_curl_openai "$@"; }
    export -f curl # Make it available

    run_test "query_openai (mocked success)"         "assert_output_equals 'query_ai "openai" "gpt-4o" "Test prompt" "0.5"' 'Mocked OpenAI response'"

    # Restore curl
    unset -f curl
    if [[ -n "$original_curl_path" ]]; then
        # This doesn't really restore it for subshells of sourced scripts in bash unless we re-source them or restart.
        # For more robust mocking, the mock_api_server.sh is preferred.
        # For now, this test relies on the local function override.
        : # No perfect way to restore curl globally here without altering PATH or re-sourcing.
    fi
    unset OPENAI_API_KEY


    # Test Claude query (mocked)
    export ANTHROPIC_API_KEY="sk-ant-mockapikey"
    update_config_value "$MOCK_CONFIG_FILE" "CLAUDE_MODEL" "claude-3-opus-20240229"
    curl() { mock_curl_claude "$@"; } # Redefine for Claude
    export -f curl

    run_test "query_claude (mocked success)"         "assert_output_equals 'query_ai "claude" "claude-3-opus-20240229" "Test prompt" "0.5"' 'Mocked Claude response'"

    unset -f curl
    unset ANTHROPIC_API_KEY

    # Ollama query test (relies on actual ollama if available and configured)
    # To unit test query_ollama, `ollama run` would need to be mocked.
    if command -v ollama >/dev/null && pgrep -f "ollama serve" >/dev/null; then
        local ollama_test_model
        ollama_test_model=$(get_ollama_models | head -n 1)
        if [[ -n "$ollama_test_model" ]]; then
            update_config_value "$MOCK_CONFIG_FILE" "OLLAMA_MODEL" "$ollama_test_model"
            # This is an integration test as it calls actual ollama
            # run_test "query_ollama (live if ollama available)"             #   "assert_output_contains 'query_ai "ollama" "$ollama_test_model" "Explain testing in one word." "0.1"' ''"
            # The above would check for non-empty, but it's too integration-heavy for this script.
            log "INFO: Live Ollama query test skipped in this unit test script. Covered by manual or integration tests."
        fi
    fi
}


test_query_ai_with_fallback_mocked() {
    # Setup config: Primary OpenAI (mocked to fail), Fallback Claude (mocked to succeed)
    update_config_value "$MOCK_CONFIG_FILE" "AI_PROVIDER" "openai"
    update_config_value "$MOCK_CONFIG_FILE" "OPENAI_MODEL" "gpt-4o"
    update_config_value "$MOCK_CONFIG_FILE" "FALLBACK_PROVIDERS" "claude"
    update_config_value "$MOCK_CONFIG_FILE" "CLAUDE_MODEL" "claude-3-opus-20240229"

    export OPENAI_API_KEY="sk-mockapikeyfail"
    export ANTHROPIC_API_KEY="sk-ant-mockapikeysucceed"

    # Mock curl: OpenAI fails, Claude succeeds
    mock_curl_fallback() {
        if [[ "$*" == *api.openai.com* ]]; then
            echo "Mocked OpenAI failure" >&2
            echo "400" # Simulate failure
            return 1
        elif [[ "$*" == *api.anthropic.com* ]]; then
            echo "Mocked Claude success during fallback" >&2
             echo '{ "content": [ { "type": "text", "text": "Mocked Claude fallback response" } ] }'
            echo "200"
            return 0
        fi
        return 1
    }
    curl() { mock_curl_fallback "$@"; }
    export -f curl

    run_test "query_ai_with_fallback (OpenAI fails, Claude succeeds)"         "assert_output_equals 'query_ai_with_fallback "Test fallback prompt"' 'Mocked Claude fallback response'"

    unset -f curl
    unset OPENAI_API_KEY
    unset ANTHROPIC_API_KEY
}


# --- Main Test Execution ---
echo "Starting test_ai_providers.sh..."
setup_mock_environment

# Run test suites
test_api_key_validation
test_api_key_retrieval_and_storage
test_provider_detection
test_model_lists_and_validation
test_query_ai_functions_mocked # Uses function-level curl mocks
test_query_ai_with_fallback_mocked # Uses function-level curl mocks


cleanup_mock_environment

echo "--------------------------------------------------"
echo "Tests finished."
echo "Total tests: $TEST_NUM"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo "--------------------------------------------------"

if [ $FAILED_TESTS -eq 0 ]; then
    exit 0
else
    exit 1
fi
