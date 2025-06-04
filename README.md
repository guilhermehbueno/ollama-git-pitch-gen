# Ollama Git Pitch Generator 🚀

**Generate compelling Git commit messages, PR descriptions, README sections, and get codebase insights using the power of Large Language Models, now with multi-provider support (Ollama, OpenAI, Claude)!**

`ollama-git-pitch-gen` (or `pitch` for short) is a command-line tool designed to streamline your Git workflow by leveraging AI to generate high-quality text for your repository. Whether you need a concise commit message, a detailed PR summary, or help understanding code changes, `pitch` has you covered.

This tool integrates directly with your Git environment and uses a configurable AI backend to provide intelligent suggestions and summaries.

## Features ✨

*   **Multi-AI Provider Support**: Seamlessly switch between Ollama (for local models), OpenAI (GPT models), and Anthropic (Claude models).
*   **Automatic Commit Message Generation**: Get AI-powered suggestions for your commit messages based on staged changes.
*   **Pull Request Description Generation**: Automatically create detailed PR titles and descriptions from your diffs.
*   **README Generation**: Summarize your project files and generate a draft README.md.
*   **Interactive Code Q&A (`ask` command)**: Ask questions about your codebase and get answers from your chosen AI provider.
*   **Git Hook Integration**: Automatically generate commit messages when you run `git commit` (configurable).
*   **Customizable Prompts**: Tailor the AI's behavior with custom prompt templates.
*   **Configurable Models & Temperatures**: Choose different models and creativity levels for each provider.
*   **Fallback Providers**: Ensure you always get a response, even if your primary AI provider fails.
*   **Easy Installation & Setup**: Get started quickly with a simple installation script.

## Prerequisites 📋

*   **Git**: Essential for version control and interacting with your repository.
*   **Gum**: For beautiful TUI interactions. `install.sh` attempts to install it.
*   **jq**: For JSON processing in API interactions. `install.sh` attempts to install it.
*   **Ollama (Optional but Recommended)**: If you plan to use local models via Ollama. Visit [ollama.com](https://ollama.com) for installation.
*   **API Keys (Optional)**: If using OpenAI or Anthropic (Claude) models, you'll need API keys from these providers.

## Installation 💻

1.  **Clone the repository (or use the installer for the latest release):**
    ```bash
    # For developers contributing to this tool:
    git clone https://github.com/guilhermehbueno/ollama-git-pitch-gen.git
    cd ollama-git-pitch-gen
    # Run the installer from the cloned repo to set up dependencies and the 'pitch' command
    ./install.sh
    ```
    For users, it's recommended to use the installer command directly from the README of the original repository, which usually looks like:
    ```bash
    curl -sSL https://raw.githubusercontent.com/guilhermehbueno/ollama-git-pitch-gen/main/install.sh | bash
    ```

2.  **Follow the on-screen instructions.** The installer will:
    *   Check for dependencies like Git, Gum, and jq (and attempt to install Gum/jq if missing).
    *   Clone the necessary files to `$HOME/.ollama-git-pitch-gen`.
    *   Create a symlink for the `pitch` command in `$HOME/.local/bin`.
    *   Guide you through Ollama setup (if you choose to install it) and default model creation.
    *   Prompt for API Key configuration.

3.  **Ensure `$HOME/.local/bin` is in your PATH.**
    The script will attempt to add it to your shell profile (e.g., `.bashrc`, `.zshrc`). You might need to restart your shell or source your profile file:
    ```bash
    source ~/.bashrc  # or ~/.zshrc, ~/.profile, etc.
    ```

### API Key Configuration

For **OpenAI** and **Anthropic (Claude)**, API keys are required. You have a few ways to configure them:

1.  **Environment Variables (Recommended)**:
    *   Set `OPENAI_API_KEY` for OpenAI.
    *   Set `ANTHROPIC_API_KEY` for Anthropic.
    ```bash
    export OPENAI_API_KEY="your_openai_api_key_here"
    export ANTHROPIC_API_KEY="your_anthropic_api_key_here"
    ```
    Add these to your shell profile (e.g., `~/.bashrc`, `~/.zshrc`) for persistence.

2.  **API Key Files**:
    *   Store your OpenAI key in `~/.openai/api_key`.
    *   Store your Anthropic key in `~/.anthropic/api_key`.
    The `pitch install` script or `pitch setup-keys` command can help you create these files securely.
    You can also specify custom paths in the configuration file (see below).

3.  **`pitch setup-keys` Command**:
    Run `pitch setup-keys` after installation to be interactively prompted for your API keys. The tool will store them in the default file locations.

## Usage 🛠️

The `pitch` command is your entry point.

```bash
pitch <command> [options]
```

### General Workflow

1.  **Configure your AI Provider (Optional first step)**:
    *   Run `pitch model` within a Git repository to select your primary AI provider (Ollama, OpenAI, or Claude) and a specific model for that provider for the current project. This saves to a project-local config.
    *   If using OpenAI or Claude, ensure your API keys are set up (see API Key Configuration or run `pitch setup-keys`).
    *   Use `pitch providers` to see the current status and configuration of all providers.

2.  **Generate Commit Messages**:
    *   Stage your changes: `git add .`
    *   Run `pitch commit`. An AI-generated commit message will be suggested.
    *   You can refine the message or accept it.

3.  **Generate PR Descriptions**:
    *   Ensure your branch is pushed and you have a base branch to compare against.
    *   Run `pitch pr <base_branch>` (e.g., `pitch pr main`).
    *   A PR title and description will be generated. If `gh` (GitHub CLI) is installed, you'll be prompted to create the PR.

4.  **Ask Questions About Your Code**:
    *   Run `pitch ask "Your question about the codebase"`
    *   Select the provider and model you want to use for the answer.

5.  **Generate a README**:
    *   Run `pitch readme` to generate a draft README.md based on your project files.

## Command Reference 📜

Here are the main commands available with `pitch`:

*   **`pitch help`**: Displays the help message.
*   **`pitch install`**: (Primarily for `install.sh` script) Sets up Ollama, default models, and guides API key setup.
*   **`pitch uninstall`**: Removes Ollama models, the `pitch` command, and related files.
*   **`pitch apply`**: Installs the Git `prepare-commit-msg` hook in the current repository, enabling automatic commit message suggestions.
*   **`pitch model`**: Interactively select your primary AI provider (Ollama, OpenAI, Claude) and then choose a specific model for that provider. The selected provider and model will be saved to the project's configuration (`.git/hooks/prepare-commit-msg.properties`).
*   **`pitch providers`**: Shows the status of all available AI providers, their configured models, temperatures, and roles (primary/fallback).
*   **`pitch setup-keys`**: Interactively prompts the user to enter API keys for OpenAI and Claude, storing them securely in default file locations.
*   **`pitch commit [-p "Additional context"]`**: Generates a commit message for staged changes.
    *   `-p "..."`: Provide additional context or instructions for the AI.
*   **`pitch pr <base_branch> [--text-only]`**: Generates a PR title and description.
    *   `<base_branch>`: The branch to compare against (e.g., `main`, `develop`).
    *   `--text-only`: Only output the markdown, don't attempt to create a PR via `gh`.
*   **`pitch ask ["Your question"]`**: Ask a question about your codebase. If no question is provided as an argument, `gum` will prompt for input.
*   **`pitch readme [--ignore "pattern1,pattern2"]`**: Generates a README.md for the project.
    *   `--ignore "..."`: Comma-separated list of glob patterns to ignore (e.g., `"*/node_modules/*,*.log"`).
*   **`pitch update`**: Updates `pitch` to the latest version from the Git repository.
*   **`pitch start`**: Starts the Ollama server (if Ollama is your chosen provider).
*   **`pitch stop`**: Stops the Ollama server.
*   **`pitch info`**: Displays information about the current configuration and models (being updated for multi-provider).
*   **`pitch create_model <base_ollama_model>`**: (Ollama-specific) Creates a new `pitch_*` prefixed model in Ollama from a base model (e.g., `pitch create_model llama3:latest` creates `pitch_llama3:latest`). Requires a `Modelfile.sample` in the installation directory.
*   **`pitch delete_models`**: (Ollama-specific) DANGEROUS! Removes ALL local Ollama models and data from `~/.ollama/models`.
*   **`pitch remove_pitch_models`**: (Ollama-specific) Removes all Ollama models prefixed with `pitch_`.
*   **`pitch test-connection [provider_name]`**: Tests the connection to the specified provider (e.g., `ollama`, `openai`, `claude`). If no provider is named, it will prompt for selection.

## Configuration ⚙️

`pitch` uses a properties file for configuration. When you run `pitch apply` or `pitch model` in a repository, a project-specific configuration is created at `.git/hooks/prepare-commit-msg.properties`. If no project-specific configuration is found, it may fall back to a global configuration at `$INSTALL_DIR/prepare-commit-msg.properties` (`$HOME/.ollama-git-pitch-gen/prepare-commit-msg.properties`).

Here's an example of the `prepare-commit-msg.properties` format:

```properties
# =============================================================
# Multi-AI Provider Configuration for Git Pitch Generator
# =============================================================

# Primary AI Provider (ollama, openai, claude)
# This is the first provider 'pitch' will try to use.
AI_PROVIDER=ollama

# Fallback Providers (comma-separated, tried in order if primary fails)
# If the primary provider fails, 'pitch' will try these providers in the order listed.
# Example: FALLBACK_PROVIDERS=openai,claude
# Example: FALLBACK_PROVIDERS=claude
# Example: FALLBACK_PROVIDERS=  (to disable fallbacks)
FALLBACK_PROVIDERS=openai,claude

# =============================================================
# Model Configuration (per provider)
# =============================================================
# Ensure these are valid model names for each provider.
# For Ollama, these are names of models you have pulled or created (e.g., pitch_mymodel:latest).
# For OpenAI/Claude, these are specific API model identifiers.

OLLAMA_MODEL=pitch_llama3.1:latest
# Common OpenAI Models: gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo
OPENAI_MODEL=gpt-4o-mini
# Common Claude Models: claude-3-5-sonnet-20240620, claude-3-opus-20240229, claude-3-sonnet-20240229, claude-3-haiku-20240307
CLAUDE_MODEL=claude-3-5-sonnet-20240620

# =============================================================
# Temperature Settings (creativity level: 0.0-1.0)
# =============================================================
# These are default temperatures if not overridden by specific command logic.
# Higher values (e.g., 0.8) make output more random/creative.
# Lower values (e.g., 0.2) make output more focused/deterministic.
OLLAMA_TEMPERATURE=0.7
OPENAI_TEMPERATURE=0.7
CLAUDE_TEMPERATURE=0.7

# =============================================================
# API Configuration (optional - prefer environment variables)
# =============================================================
# If API keys are not set as environment variables (OPENAI_API_KEY, ANTHROPIC_API_KEY),
# you can specify paths to files containing the keys.
# Example:
# OPENAI_API_KEY_FILE=~/.openai/api_key
# ANTHROPIC_API_KEY_FILE=~/.anthropic/api_key

# =============================================================
# Legacy Settings (for backward compatibility or specific features)
# =============================================================
# UNIFIED_LINES: For git diff context in some prompts (not universally used by all prompt templates)
UNIFIED_LINES=50
# ALLOW_COMMIT_OVERRIDE: If true, AI suggestions populate commit message directly. If false, they are commented. (prepare-commit-msg.sh hook behavior)
ALLOW_COMMIT_OVERRIDE=true
# OLLAMA_PROMPT: Legacy global prompt for Ollama. New system uses per-command prompts. May be ignored.
OLLAMA_PROMPT=""
# MAX_DIFF_LINES: Max diff lines to feed into prompts like commit message generation.
MAX_DIFF_LINES=500
```

### Key Configuration Options:

*   `AI_PROVIDER`: Your preferred primary AI service (`ollama`, `openai`, `claude`).
*   `FALLBACK_PROVIDERS`: A comma-separated list of providers to try if the primary one fails (e.g., `openai,claude`).
*   `OLLAMA_MODEL`, `OPENAI_MODEL`, `CLAUDE_MODEL`: The specific model identifier for each provider.
*   `OLLAMA_TEMPERATURE`, `OPENAI_TEMPERATURE`, `CLAUDE_TEMPERATURE`: Creativity level for each provider (0.0 to 1.0).
*   `OPENAI_API_KEY_FILE`, `ANTHROPIC_API_KEY_FILE`: Paths to API key files if not using environment variables.
*   `MAX_DIFF_LINES`: Controls how much of the `git diff` is sent to the AI for context.
*   `ALLOW_COMMIT_OVERRIDE`: For the `prepare-commit-msg` hook. If `true`, the AI message is directly used. If `false`, it's added as a comment in your commit message file.

## Multi-Provider Setup Guide

`pitch` allows you to use different AI backends. Here’s how to set them up:

### 1. Ollama (Local Models)

*   **Install Ollama**: Download and install from [ollama.com](https://ollama.com). The `pitch install` script can also guide you through this.
*   **Pull Models**: Download models to run locally.
    ```bash
    ollama pull llama3.1   # Example: Llama 3.1 (8B model)
    ollama pull codellama  # Example: CodeLlama
    ollama pull mistral    # Example: Mistral
    # List available models with `ollama list`
    ```
*   **Create `pitch_*` Models (Optional but Recommended)**: `pitch` often uses models prefixed with `pitch_` which are derived from base Ollama models but can include specific system prompts or parameters via a Modelfile.
    *   Run `pitch create_model <base_model_name>` (e.g., `pitch create_model llama3.1:latest`). This looks for `Modelfile.sample` in your `pitch` installation directory (`~/.ollama-git-pitch-gen`), substitutes the base model, and creates a new model like `pitch_llama3.1:latest`.
    *   You can customize `Modelfile.sample` before creating models.
*   **Configure in `pitch`**: Run `pitch model`, select `ollama`, and choose your desired `pitch_` model (or any other Ollama model you have).

### 2. OpenAI (GPT Models)

*   **Obtain API Key**: Sign up at [OpenAI](https://platform.openai.com/) and get an API key.
*   **Set Up API Key**:
    *   **Environment Variable (Recommended)**: `export OPENAI_API_KEY="your_key_here"` (add to your shell profile).
    *   **Key File**: Use `pitch setup-keys` to store it, or manually save your key to `~/.openai/api_key`.
    *   **Config File**: Specify `OPENAI_API_KEY_FILE=/path/to/your/keyfile` in `prepare-commit-msg.properties`.
*   **Choose a Model**:
    *   Common models: `gpt-4o`, `gpt-4o-mini`, `gpt-4-turbo`, `gpt-3.5-turbo`.
    *   Run `pitch model`, select `openai`, and choose from the available models (or ensure the one you want is listed in `ai_providers.sh` and correctly set in your config).
*   **Cost**: Be aware that OpenAI API usage is charged per token.

### 3. Anthropic (Claude Models)

*   **Obtain API Key**: Sign up at [Anthropic](https://www.anthropic.com/) and get an API key.
*   **Set Up API Key**:
    *   **Environment Variable (Recommended)**: `export ANTHROPIC_API_KEY="your_key_here"` (add to your shell profile).
    *   **Key File**: Use `pitch setup-keys` to store it, or manually save your key to `~/.anthropic/api_key`.
    *   **Config File**: Specify `ANTHROPIC_API_KEY_FILE=/path/to/your/keyfile` in `prepare-commit-msg.properties`.
*   **Choose a Model**:
    *   Common models: `claude-3-5-sonnet-20240620`, `claude-3-opus-20240229`, `claude-3-sonnet-20240229`, `claude-3-haiku-20240307`.
    *   Run `pitch model`, select `claude`, and choose from the available models (or ensure the one you want is listed in `ai_providers.sh` and correctly set in your config).
*   **Cost**: Anthropic API usage is also charged.

## Git Hook Integration 🎣

`pitch` can integrate with the `prepare-commit-msg` Git hook.

1.  Navigate to your Git repository.
2.  Run `pitch apply`.

This copies the `prepare-commit-msg.sh` script and a default `prepare-commit-msg.properties` configuration file into your repository's `.git/hooks/` directory.

Now, when you run `git commit`:
*   The hook will trigger `pitch commit` automatically.
*   The suggested commit message will be populated in your editor (or used directly if `ALLOW_COMMIT_OVERRIDE=true` and you commit with `git commit -m "dummy message"`).
*   The hook uses the multi-provider configuration from `.git/hooks/prepare-commit-msg.properties`.

## Prompt Customization ✍️

You can customize the prompts used by `pitch` for different actions (commit messages, PR descriptions, etc.). Default prompt files are located in the installation directory (`$HOME/.ollama-git-pitch-gen`).

*   `commit.prompt`: Used for generating commit messages.
*   `pr-description.prompt`: Used for generating PR descriptions.
*   `pr-title.prompt`: Used for generating PR titles.
*   `readme.prompt` (or similar, exact name might vary): Used for README generation.

To customize for a specific project:
1.  Copy the default prompt files from `$INSTALL_DIR` to your project's `.git/hooks/` directory.
2.  Modify the copied files. `pitch` will use these project-specific prompts if they exist.

**Prompt Template Variables**:
*   `$DIFF_CONTENT`: Replaced with the relevant Git diff.
*   `$BRANCH_NAME`: Replaced with the current branch name.
*   `$FILES_SUMMARY`: (For READMEs) Replaced with summaries of project files.
*   Other variables might be available depending on the specific command.

## Troubleshooting  Tips 🔍

*   **"No AI providers available"**:
    *   Ensure Ollama is running if it's your selected provider (`ollama list` should work).
    *   For OpenAI/Claude, check that your API keys are correctly set as environment variables or in the specified key files. Use `pitch test-connection <provider>` to diagnose.
    *   Run `pitch providers` to see the status of each provider.
*   **API Key Errors (401/403 Unauthorized/Forbidden)**:
    *   Double-check your API keys for typos.
    *   Ensure your OpenAI/Anthropic account has credit or is active.
*   **Model Not Found (for OpenAI/Claude)**:
    *   Verify the model name in `prepare-commit-msg.properties` is correct and available for your API key. Check the provider's documentation for valid model names. The default lists in `ai_providers.sh` should be up-to-date but can be extended.
*   **Ollama Model Not Found**:
    *   Ensure you have pulled the model (`ollama pull mymodel`) or created the `pitch_` prefixed model (`pitch create_model mymodel`).
    *   `ollama list` should show the model you're trying to use.
*   **Fallback Not Working**:
    *   Ensure `FALLBACK_PROVIDERS` in your config lists valid, configured providers.
    *   Test each fallback provider individually using `pitch model` to set it as primary, then try a command.
*   **`curl` / `jq` errors**: Ensure `curl` and `jq` are installed and in your PATH. `install.sh` attempts to install `jq`.
*   **`gum` errors**: Ensure `gum` is installed. `install.sh` attempts this.
*   **Log Files**: Check `~/.ollama_server.log` for Ollama server issues. `pitch` commands also log to stdout/stderr (unless `-q` or `--no-logs` is used).

## Cost Considerations 💰

Using cloud-based AI providers like OpenAI and Anthropic (Claude) will incur costs based on your usage (typically per token processed).

*   Monitor your API usage dashboards on the respective provider websites.
*   Choose smaller/cheaper models (e.g., `gpt-4o-mini`, `claude-3-haiku`) for less critical tasks if cost is a concern.
*   Leverage local Ollama models for free, high-quality alternatives, especially for frequent use.

## Contributing 🤝

Contributions are welcome! Please fork the repository, make your changes, and submit a pull request. Ensure your changes are well-tested.

## License 📄

This project is licensed under the MIT License. See the `LICENSE` file for details.
