#!/bin/bash

# Define constants
MODEL_NAME="lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF"
HUGGINGFACE_URL="https://huggingface.co/lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF"
MODEL_DIR="$HOME/models"
MODEL_ALIAS="git-assistant"
MODEL_FILE="./Modelfile"
SYSTEM_PROMPT="You are an AI expert in answering questions accurately."

# Function to install Ollama
install_ollama() {
    echo "Installing Ollama..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS installation using Homebrew
        if ! command -v brew >/dev/null 2>&1; then
            echo "Homebrew not found. Please install Homebrew first."
            exit 1
        fi
        brew install ollama
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation
        echo "Please install Ollama manually from https://ollama.ai."
        exit 1
    else
        echo "Unsupported OS. Please install Ollama manually from https://ollama.ai."
        exit 1
    fi
}

# Function to check if Ollama is installed
check_or_install_ollama() {
    if ! command -v ollama >/dev/null 2>&1; then
        echo "Ollama not found. Installing..."
        install_ollama
    else
        echo "Ollama is already installed."
    fi
}

# Function to start Ollama server
start_ollama_server() {
    if ! pgrep -f "ollama serve" >/dev/null 2>&1; then
        echo "Starting Ollama server..."
        ollama serve &
        sleep 2  # Allow time for the server to start
    else
        echo "Ollama server is already running."
    fi
}

# Function to ensure the model is available locally
ensure_model_available() {
    if ! ollama list | grep -q "$MODEL_NAME"; then
        echo "Model '$MODEL_NAME' not found locally. Downloading..."
        ollama pull "$HUGGINGFACE_URL"
        if [[ $? -ne 0 ]]; then
            echo "Failed to download model '$MODEL_NAME'. Exiting..."
            exit 1
        fi
        echo "Model '$MODEL_NAME' downloaded successfully."
    else
        echo "Model '$MODEL_NAME' is already available locally."
    fi
}

# Function to create the Ollama alias
create_model_alias() {
    if ollama list | grep -q "$MODEL_ALIAS"; then
        echo "Model alias '$MODEL_ALIAS' already exists. Skipping creation."
    else
        echo "Creating model alias '$MODEL_ALIAS'..."
        ollama create "$MODEL_ALIAS" -f "$MODEL_FILE"
        if [[ $? -ne 0 ]]; then
            echo "Failed to create model alias '$MODEL_ALIAS'. Exiting..."
            exit 1
        fi
        echo "Model alias '$MODEL_ALIAS' created successfully."
    fi
}

# Function to test the model with a sample prompt
test_model() {
    SAMPLE_DIFF="diff --git a/src/main.py b/src/main.py index 3f2b16e..b67f9c4 100644 --- a/src/main.py +++ b/src/main.py @@ -1,6 +1,7 @@ import os import sys import logging +import json def main(): logging.basicConfig(level=logging.INFO) @@ -10,6 +11,9 @@ def main(): logging.error('No arguments provided!') sys.exit(1) +config_file = 'config.json' +with open(config_file, 'r') as file: +config = json.load(file) for arg in args: logging.info(f'Processing argument: {arg}')"
    echo "Testing the model with a sample diff..."
    RESPONSE=$(ollama run "$MODEL_ALIAS" "Generate a commit message for the following change: $SAMPLE_DIFF")
    if [[ $? -eq 0 ]]; then
        echo "Model response:"
        echo "$RESPONSE"
    else
        echo "Failed to get a response from the model."
    fi
}

# Main execution flow
check_or_install_ollama
start_ollama_server
ensure_model_available
create_model_alias
test_model