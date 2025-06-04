#!/bin/bash

# Simple Mock API Server for OpenAI and Claude using netcat (nc) or ncat
# This server is very basic and handles one request at a time.
# It's intended for controlled testing of API call structures and responses.

PORT="${MOCK_API_PORT:-8080}" # Use MOCK_API_PORT from env if set, else 8080
LOG_FILE="$PWD/mock_api_server.log" # Log requests in the current directory

# --- Response Configuration ---
# These can be dynamically changed by tests if needed, e.g., by writing to temp files
# and having the server read from them. For simplicity, they are hardcoded or controlled by env vars here.

OPENAI_MOCK_RESPONSE_FILE="/tmp/openai_mock_response.json"
CLAUDE_MOCK_RESPONSE_FILE="/tmp/claude_mock_response.json"
OPENAI_MOCK_STATUS_CODE_FILE="/tmp/openai_mock_status_code.txt"
CLAUDE_MOCK_STATUS_CODE_FILE="/tmp/claude_mock_status_code.txt"

# Default responses
echo '{ "choices": [ { "message": { "role": "assistant", "content": "Default mock OpenAI response" } } ] }' > "$OPENAI_MOCK_RESPONSE_FILE"
echo "200" > "$OPENAI_MOCK_STATUS_CODE_FILE"

echo '{ "content": [ { "type": "text", "text": "Default mock Claude response" } ] }' > "$CLAUDE_MOCK_RESPONSE_FILE"
echo "200" > "$CLAUDE_MOCK_STATUS_CODE_FILE"


log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to handle an incoming request
handle_request() {
    local request_data=""
    local content_length=0
    local line

    # Read HTTP headers
    while IFS= read -r line && [[ -n "${line//[$'\r\n']}" ]]; do # Stop on empty line
        request_data+="$line\n"
        if [[ "$line" =~ ^Content-Length:\ ([0-9]+) ]]; then
            content_length="${BASH_REMATCH[1]}"
        fi
    done

    # Read body if Content-Length > 0
    local request_body=""
    if [[ "$content_length" -gt 0 ]]; then
        IFS= read -r -n "$content_length" request_body
        request_data+="\n$request_body" # Add body to full request log
    fi

    log_message "--- New Request ---"
    log_message "Request Headers & Body:\n$request_data"

    local response_body=""
    local status_code="200"
    local content_type="application/json"

    # Determine if it's an OpenAI or Claude request based on path (simplistic)
    if echo "$request_data" | grep -q "POST /v1/chat/completions"; then
        log_message "Serving OpenAI mock response."
        response_body=$(cat "$OPENAI_MOCK_RESPONSE_FILE")
        status_code=$(cat "$OPENAI_MOCK_STATUS_CODE_FILE")
        # Simulate rate limit error if specific status code is set
        if [[ "$status_code" == "429" ]]; then
            response_body='{ "error": { "message": "Rate limit exceeded (mock)", "type": "rate_limit_error", "code": "rate_limit_exceeded" } }'
        elif [[ "$status_code" != "200" ]]; then
             response_body='{ "error": { "message": "Mock OpenAI Error", "type": "api_error", "code": null } }'
        fi

    elif echo "$request_data" | grep -q "POST /v1/messages"; then
        log_message "Serving Claude mock response."
        response_body=$(cat "$CLAUDE_MOCK_RESPONSE_FILE")
        status_code=$(cat "$CLAUDE_MOCK_STATUS_CODE_FILE")
        if [[ "$status_code" == "429" ]]; then
            response_body='{ "error": { "type": "error", "error": { "type": "rate_limit_error", "message": "Rate limit exceeded (mock)" } } }'
        elif [[ "$status_code" != "200" ]]; then
            response_body='{ "error": { "type": "error", "error": { "type": "api_error", "message": "Mock Claude Error" } } }'
        fi
    else
        log_message "Unknown request path. Serving 404."
        status_code="404"
        response_body='{ "error": "Not Found" }'
    }

    # Construct HTTP response
    # Ensure status message matches code
    local status_message="OK"
    if [[ "$status_code" == "400" ]]; then status_message="Bad Request"; fi
    if [[ "$status_code" == "401" ]]; then status_message="Unauthorized"; fi
    if [[ "$status_code" == "403" ]]; then status_message="Forbidden"; fi
    if [[ "$status_code" == "404" ]]; then status_message="Not Found"; fi
    if [[ "$status_code" == "429" ]]; then status_message="Too Many Requests"; fi
    if [[ "$status_code" == "500" ]]; then status_message="Internal Server Error"; fi

    printf "HTTP/1.1 %s %s\r\n" "$status_code" "$status_message"
    printf "Content-Type: %s\r\n" "$content_type"
    printf "Content-Length: %s\r\n" "${#response_body}"
    printf "Connection: close\r\n"
    printf "\r\n"
    printf "%s" "$response_body"

    log_message "Responded with Status: $status_code"
    log_message "Response Body:\n$response_body"
}


# --- Main Server Loop ---
echo "Mock API server starting on port $PORT..."
echo "Logging to $LOG_FILE"
rm -f "$LOG_FILE" # Clear log on start

# Check for netcat variant
if command -v ncat >/dev/null; then
    NC_COMMAND="ncat -l $PORT -k --sh-exec \"$(declare -f log_message handle_request); handle_request\""
    # Using --sh-exec with full function definitions. declare -f gets the function source.
    # Ensure handle_request and log_message are self-contained or also declared if needed by handle_request.
elif command -v nc >/dev/null; then
    if nc -h 2>&1 | grep -q "OpenBSD"; then
      # For OpenBSD nc (macOS default), -N shuts down after EOF. Loop needed.
      NC_COMMAND_LOOP="while true; do { $(declare -f log_message handle_request); handle_request | nc -l $PORT -N; } done"
      log_message "Using OpenBSD nc. Server will handle one request then nc exits, restarting loop."
    elif nc -h 2>&1 | grep -q "GNU netcat"; then
      # GNU nc with -c or -e (less common for executing shell functions directly per connection without scripts)
      # A common loop for GNU nc for basic testing:
      NC_COMMAND_LOOP="while true; do { $(declare -f log_message handle_request); handle_request | nc -l $PORT -q 0; } done"
      log_message "Using basic GNU nc loop. Ensure your nc supports -l and -q 0 (or similar)."
    else # Other nc versions
      NC_COMMAND_LOOP="while true; do { $(declare -f log_message handle_request); handle_request | nc -l $PORT; } done"
      log_message "Using generic nc loop. Behavior might vary."
    fi
else
    echo "ERROR: Neither ncat nor nc found. Cannot start mock server."
    exit 1
fi


# Cleanup function for server shutdown
cleanup_server() {
    log_message "Mock server shutting down."
    rm -f "$OPENAI_MOCK_RESPONSE_FILE" "$CLAUDE_MOCK_RESPONSE_FILE"
    rm -f "$OPENAI_MOCK_STATUS_CODE_FILE" "$CLAUDE_MOCK_STATUS_CODE_FILE"
    # Kill backgrounded netcat if any
    if [[ -n "$SERVER_PID" ]]; then kill "$SERVER_PID" 2>/dev/null; fi
    exit 0
}
trap cleanup_server SIGINT SIGTERM

if [[ -n "$NC_COMMAND_LOOP" ]]; then
    log_message "Starting server loop with nc..."
    # Export functions so they are available in the subshell created by the loop
    export -f log_message
    export -f handle_request
    eval "$NC_COMMAND_LOOP" &
    SERVER_PID=$!
    wait "$SERVER_PID" # Wait for the loop to be killed
else
    log_message "Starting server with: $NC_COMMAND"
    eval "$NC_COMMAND" &
    SERVER_PID=$!
    wait "$SERVER_PID" # Wait for ncat to be killed
fi

# Fallback if trap doesn't run (e.g. script killed with -9)
cleanup_server
