#!/bin/bash

# ───────────────────────────────────────────────────────────
# 🔹 DEFAULT CONFIGURATION VARIABLES
# ───────────────────────────────────────────────────────────

# AI Model & Prompt Settings
OLLAMA_MODEL="git-assistant"
OLLAMA_PROMPT="Generate a meaningful Git commit message for the following change:"
OLLAMA_PROMPT_EXTRA=""
OLLAMA_RETRIES=2  # Number of retries if Ollama fails

# Git Hook Behavior
MAX_DIFF_LINES=100  # Limit the number of lines in the diff
MIN_DIFF_LINES=1    # Minimum lines required to trigger AI message generation
DIFF_CONTEXT_LINES=3    # Minimum lines required to trigger AI message generation
ALLOW_COMMIT_OVERRIDE=true  # If false, AI-generated message is appended as a comment

# System & Paths
OLLAMA_SERVER_PORT=11434  # Default Ollama port
OLLAMA_CMD="ollama"       # Change this if Ollama is installed elsewhere
TEMP_FILE="/tmp/ollama_commit_message"  # Ensures no unwanted files in the repo
CONFIG_FILE=".git/hooks/prepare-commit-msg.properties"  # Path to user-defined config

# ───────────────────────────────────────────────────────────
# 🔹 LOAD USER CONFIGURATION (IF EXISTS)
# ───────────────────────────────────────────────────────────

if [[ -f "$CONFIG_FILE" ]]; then
    echo "🔧 Loading user configuration from $CONFIG_FILE..."
    while IFS='=' read -r key value; do
        if [[ ! -z "$key" && ! "$key" =~ ^#.* ]]; then  # Ignore empty lines and comments
            key=$(echo "$key" | tr -d ' ')  # Remove spaces from key
            value=$(echo "$value" | tr -d ' ')  # Remove spaces from value
            declare "$key=$value"
        fi
    done < "$CONFIG_FILE"
fi

# Convert boolean variables correctly
ALLOW_COMMIT_OVERRIDE=$(echo "$ALLOW_COMMIT_OVERRIDE" | tr '[:upper:]' '[:lower:]')
if [[ "$ALLOW_COMMIT_OVERRIDE" != "true" && "$ALLOW_COMMIT_OVERRIDE" != "false" ]]; then
    echo "⚠️  Invalid value for ALLOW_COMMIT_OVERRIDE in $CONFIG_FILE. Defaulting to 'true'."
    ALLOW_COMMIT_OVERRIDE=true
fi

# ───────────────────────────────────────────────────────────
# 🔹 FUNCTION DEFINITIONS
# ───────────────────────────────────────────────────────────

# Ensure old temporary files are removed
rm -f "$TEMP_FILE"

# Function to get the git diff
get_git_diff() {
    local diff
    diff=$(git diff --cached --unified=$DIFF_CONTEXT_LINES --no-color)

    if [[ $(echo "$diff" | wc -l) -gt $MAX_DIFF_LINES ]]; then
        echo "⚠️  Diff too long. Truncating to last 50 lines."
        diff=$(echo "$diff" | tail -n $MAX_DIFF_LINES)
    fi

    echo "$diff"
}

# Function to check if Ollama is running
is_ollama_running() {
    if ! lsof -i :$OLLAMA_SERVER_PORT >/dev/null 2>&1; then
        echo "❌ Ollama server is NOT running. Please start it with 'ollama serve'."
        exit 1
    fi
}

# Function to generate commit message using Ollama
generate_commit_message() {
    local diff="$1"
    local result

    echo "📄 Model: $OLLAMA_MODEL"
    is_ollama_running  # Ensure Ollama is running before calling it

    local compounded_prompt="$OLLAMA_PROMPT\n$OLLAMA_PROMPT_EXTRA"
    result=$($OLLAMA_CMD run "$OLLAMA_MODEL" "$compounded_prompt $diff" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo "⚠️  Ollama failed to generate a message. Retrying..."
        sleep 2
        result=$($OLLAMA_CMD run "$OLLAMA_MODEL" "$compounded_prompt $diff" 2>/dev/null)

        if [[ $? -ne 0 ]]; then
            echo "❌ Failed to generate commit message after retrying. Keeping manual message."
            return 1
        fi
    fi

    # Process DeepSeek's output to move <think> content into a comment
    process_commit_message "$result"
}

process_commit_message() {
    local raw_message="$1"
    local processed_message=""
    local think_comment=""
    local inside_think=0  # Flag to track if we're inside <think> block

    # Read the message line by line
    while IFS= read -r line; do
        if [[ "$line" =~ "<think>" ]]; then
            inside_think=1
            think_comment+="# THINK: ${line//<think>/}\n"  # Start comment, remove <think>
            continue
        fi

        if [[ "$line" =~ "</think>" ]]; then
            inside_think=0
            think_comment+="# ${line//<\/think>/}\n"  # Remove </think>, keep as comment
            continue
        fi

        if [[ "$inside_think" -eq 1 ]]; then
            think_comment+="# $line\n"  # Convert every line inside <think> to a comment
        else
            processed_message+="$line\n"  # Keep other lines unchanged
        fi
    done <<< "$raw_message"

    # Return the final commit message with <think> section converted into comments
    echo -e "$processed_message\n$think_comment"
}

# ───────────────────────────────────────────────────────────
# 🔹 MAIN HOOK LOGIC
# ───────────────────────────────────────────────────────────

if [ -z "$1" ] || [ "$1" == ".git/COMMIT_EDITMSG" ]; then
    DIFF=$(get_git_diff)

    # Check if there is a diff to process
    if [ -n "$DIFF" ]; then
        echo "📄 Staged diff detected."

        if [[ $(echo "$DIFF" | wc -l) -lt $MIN_DIFF_LINES ]]; then
            echo "⚠️  Not enough changes detected to generate a meaningful commit message."
            exit 0
        fi

        COMMIT_MESSAGE=$(generate_commit_message "$DIFF")

        if [[ $? -eq 0 ]]; then
            # Preserve existing commit messages
            if [[ -s "$1" && "$ALLOW_COMMIT_OVERRIDE" == "false" ]]; then
                echo "📄 Existing commit message detected. Appending AI suggestion as a comment."
                echo -e "\n# AI-Suggested commit message:\n# $COMMIT_MESSAGE" | tee -a "$1"
            else
                echo -e "\n# Generated by $OLLAMA_MODEL:\n$COMMIT_MESSAGE" | tee -a "$1"
            fi
            echo "🔍 Review and edit your commit message before committing."
        fi
    else
        echo "⚠️  No staged changes found. Skipping commit message generation."
    fi
else
    echo "⚠️  Non-standard commit message file: $1. Skipping Ollama integration."
fi