#!/bin/bash

# SCRIPT_DIR should point to the installation directory of ollama-git-pitch-gen
# This is usually $HOME/.ollama-git-pitch-gen
# Ensure SCRIPT_DIR is correctly defined. If main.sh is a symlink, SCRIPT_DIR needs to be the actual directory.
# Using BASH_SOURCE to get the directory of the script itself (even if symlinked) might be more robust if main.sh is directly in INSTALL_DIR
if [[ -L "${BASH_SOURCE[0]}" ]]; then
    # Get the directory of the target of the symlink
    SCRIPT_DIR="$(dirname "$(readlink "${BASH_SOURCE[0]}")")"
else
    # Get the directory of the script itself
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# If main.sh is in $INSTALL_DIR, then SCRIPT_DIR is correct.
# If main.sh is a symlink in /usr/local/bin pointing to $INSTALL_DIR/main.sh, SCRIPT_DIR will be $INSTALL_DIR.

# Make SCRIPT_DIR available to sourced scripts so they can find their own dependencies if needed.
export SCRIPT_DIR

source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/model.sh" # Still needed for pitch_model, ollama specific setup, etc.
source "$SCRIPT_DIR/lib/git.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config_manager.sh" # New
source "$SCRIPT_DIR/lib/ai_providers.sh"   # New

install_gum() {
    log "Checking Gum installation..."
    if command_exists gum; then
        log "✅ Gum is already installed."
        return
    fi

    log "Installing Gum..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command_exists brew; then
            error "❌ Homebrew not found. Please install Homebrew first to install Gum." # error will exit
        fi
        if brew install gum; then
            log "✅ Gum installed successfully via Homebrew."
        else
            error "❌ Failed to install Gum using Homebrew." # error will exit
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt; then
            if sudo apt update && sudo apt install -y gum; then
                log "✅ Gum installed successfully via apt."
            else
                error "❌ Failed to install Gum using apt." # error will exit
            fi
        elif command_exists yum; then
            if sudo yum install -y gum; then
                log "✅ Gum installed successfully via yum."
            else
                error "❌ Failed to install Gum using yum." # error will exit
            fi
        else
            warn "⚠️ apt or yum not found. Please install Gum manually from https://github.com/charmbracelet/gum."
            error "Gum installation required to proceed." # error will exit
        fi
    else
        warn "❌ Unsupported OS for automatic Gum installation."
        error "Please install Gum manually from https://github.com/charmbracelet/gum and try again." # error will exit
    fi
}

info() {
    # This function should ideally source version info if available, e.g. from a VERSION file
    local version="N/A (dev)"
    if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
        version=$(cat "$SCRIPT_DIR/VERSION")
    fi

    log "Ollama Git Pitch Generator (pitch) Information:"
    gum table --widths=20,0 << EOF
"Property", "Value"
"Version", "$version"
"Installation Directory", "$INSTALL_DIR"
"Default Global Config", "$DEFAULT_CONFIG_FILE"
"Active Project Config", "$(get_active_config_file)"
"Primary AI Provider", "$(get_config_value "$(get_active_config_file)" "AI_PROVIDER" "Not Set")"
"Fallback Providers", "$(get_config_value "$(get_active_config_file)" "FALLBACK_PROVIDERS" "None")"
EOF

    # Display more detailed provider status using the existing function
    show_provider_status
}

show_help() {
    gum style --padding "1 2" --border double --border-foreground 212 "Ollama Git Pitch Generator (pitch) - Help"
    echo ""
    gum table << EOF
"Command", "Description", "Options"
"help, -h, --help", "Show this help message", ""
"install", "Run internal setup (Ollama, default models, API key guidance)", ""
"uninstall", "Remove Ollama models, pitch command, and related files", ""
"apply", "Install Git hook for automatic commit messages in current repo", ""
"model", "Interactively select AI provider and model for the current project", ""
"providers", "Show status of configured AI providers and models", ""
"setup-keys", "Interactively set up API keys for OpenAI and Claude", ""
"test-connection [provider]", "Test connection to a specific AI provider (e.g., ollama, openai, claude)", ""
"commit", "Generate AI commit message for staged changes", "[-p \"context\"]"
"pr <base_branch>", "Generate PR title and description", "[--text-only]"
"ask [\text\"]", "Ask a question about your codebase", ""
"readme", "Generate a draft README.md for your project", "[--ignore \"patterns\"]"
"update", "Update pitch to the latest version", ""
"start", "(Ollama) Start the Ollama server", ""
"stop", "(Ollama) Stop the Ollama server", ""
"create_model <base_model>", "(Ollama) Create a new pitch_* model from a base Ollama model", ""
"delete_models", "(Ollama) DANGEROUS! Remove ALL local Ollama models and data", ""
"remove_pitch_models", "(Ollama) Remove all 'pitch_*' prefixed Ollama models", ""
EOF
    echo ""
    log "For more details, see the README.md or visit the GitHub repository."
    exit 0
}

# ───────────────────────────────────────────────────────────
# 🔹 GLOBAL VARIABLES
# ───────────────────────────────────────────────────────────
# MODEL_NAME, HUGGINGFACE_URL, MODEL_DIR, MODEL_PATH might become legacy or Ollama-specific
# SYSTEM_PROMPT might also be provider-specific.
# CONFIG_FILE is now more dynamic. It can be project-specific or global.
# Let's define a function to get the appropriate config file.

# INSTALL_DIR is where the tool's own files (like default prompts) are stored.
INSTALL_DIR="$SCRIPT_DIR" # Assuming SCRIPT_DIR is $HOME/.ollama-git-pitch-gen
DEFAULT_CONFIG_FILE="$INSTALL_DIR/prepare-commit-msg.properties" # Global/default config

# Function to determine the active configuration file
get_active_config_file() {
    local git_root_val
    git_root_val=$(get_git_repo_root) # This function should handle being outside a repo gracefully

    if [[ -n "$git_root_val" && -d "$git_root_val/.git" ]]; then
        local project_config_file="$git_root_val/.git/hooks/prepare-commit-msg.properties"
        if [[ -f "$project_config_file" ]]; then
            echo "$project_config_file"
            return
        fi
        # If no project config, consider creating one or using global.
        # For now, fallback to global if no project config.
    fi

    # Fallback to global/default config file in installation directory
    # Ensure it's created if it doesn't exist
    if [[ ! -f "$DEFAULT_CONFIG_FILE" ]]; then
        create_default_config "$DEFAULT_CONFIG_FILE" # From config_manager.sh
    fi
    echo "$DEFAULT_CONFIG_FILE"
}


# Ensure CONFIG_FILE is globally available for functions in ai_providers.sh like query_ai_with_fallback
export CONFIG_FILE # This will be set by functions that need it, like commit() or globally.
CONFIG_FILE=$(get_active_config_file) # Set a default one initially. Will be overridden in functions like commit()


DISABLE_LOGS="false" # Default to false, can be overridden by args
parse_arguments "$@" # Parses --no-logs, etc.


ask() {
    local user_input="$1"
    if [[ -z "$user_input" ]]; then
        user_input=$(gum input --placeholder "Ask something..." --width "$(tput cols)")
    fi

    if [[ -z "$user_input" ]]; then
        error "No input provided."
        return 1
    fi

    local current_config_file
    current_config_file=$(get_active_config_file)

    local available_providers
    available_providers=$(get_available_providers) # From ai_providers.sh
    if [[ -z "$available_providers" ]]; then
        error "No AI providers available. Please configure one (e.g., Ollama, OpenAI, Claude)."
        return 1
    fi

    local selected_provider
    selected_provider=$(echo "$available_providers" | tr ' ' '\n' | gum choose --header "Select AI Provider:")
    if [[ -z "$selected_provider" ]]; then
        error "No provider selected."
        return 1
    fi

    log "Selected provider: $selected_provider"
    if ! validate_provider_config "$selected_provider"; then return 1; fi

    local models_list
    models_list=$(get_models_for_provider "$selected_provider") # From ai_providers.sh
    if [[ -z "$models_list" ]]; then
        error "No models available for provider $selected_provider."
        return 1
    fi

    local selected_models_str # Renamed from selected_models to avoid conflict
    selected_models_str=$(echo "$models_list" | gum choose --no-limit --header "Select Model(s) for $selected_provider:")
    if [[ -z "$selected_models_str" ]]; then
        error "No models selected."
        return 1
    fi

    IFS=$'\n' read -rd '' -a selected_models_arr <<< "$selected_models_str"

    local temperature
    temperature=$(get_config_value "$current_config_file" "${selected_provider^^}_TEMPERATURE" "0.7")

    local total_width
    total_width=$(tput cols)
    local model_count=${#selected_models_arr[@]}

    if [[ "$model_count" -eq 0 ]]; then
        error "No models selected (array empty). Exiting..."
        return 1
    fi

    local box_width=$(( total_width / model_count - (model_count * 2) )) # Adjust width dynamically

    local responses=()
    local boxes=()

    for model_name_sel in "${selected_models_arr[@]}"; do
        log "Querying $selected_provider with model $model_name_sel..."
        # query_ai(provider, model, prompt, temperature)
        local response
        response=$(query_ai "$selected_provider" "$model_name_sel" "$user_input" "$temperature")

        if [[ $? -ne 0 || -z "$response" ]]; then
            error "Failed to get response from $selected_provider model $model_name_sel."
            responses+=("Error: No response from $model_name_sel")
        else
            responses+=("$response")
        fi
    done

    local index=0
    for model_name_sel in "${selected_models_arr[@]}"; do
        local formatted_response
        formatted_response=$(echo "**🤖 $model_name_sel ($selected_provider) Response:** ${responses[$index]}" | gum format --theme=dark)
        local box
        box=$(gum style --border double --width "$box_width" --align left --padding "1 2" "$formatted_response")
        boxes+=("$box")
        ((index++))
    done

    gum join --align center "${boxes[@]}"
}


commit() {
    # User context and additional prompt handling remains the same
    local user_context=""
    local additional_prompt_text="" # Renamed to avoid conflict with prompt_file
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -m)
                user_context="$2"
                shift 2
                ;;
            -p)
                additional_prompt_text="$2" # Renamed variable
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    get_git_repo_root # Exits if not in a git repo
    # CONFIG_FILE must be set for the current git repo for query_ai_with_fallback
    export CONFIG_FILE="$git_root/.git/hooks/prepare-commit-msg.properties"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        warn "Project specific config not found at $CONFIG_FILE. Creating default."
        # This will use the default values for provider, models, etc.
        create_default_config "$CONFIG_FILE"
    fi


    local diff_content
    diff_content=$(git diff --cached --unified=0 --no-color | tail -n "$(get_config_value "$CONFIG_FILE" "MAX_DIFF_LINES" "100")")

    if [[ -z "$diff_content" ]]; then
        error "No staged changes found. Please stage files before committing."
        exit 1
    fi

    # Prompt file still comes from .git/hooks or INSTALL_DIR
    local prompt_file_path="$git_root/.git/hooks/commit.prompt"
    if [[ ! -f "$prompt_file_path" ]]; then
        # Fallback to default prompt file in installation directory
        prompt_file_path="$INSTALL_DIR/commit.prompt"
        if [[ ! -f "$prompt_file_path" ]];then
            error "Commit prompt file not found at $prompt_file_path or $INSTALL_DIR/commit.prompt"
            exit 1
        fi
    fi

    local base_prompt_content
    base_prompt_content=$(cat "$prompt_file_path")

    # Construct the initial full prompt
    local commit_prompt
    commit_prompt=$(replace_template_values "$base_prompt_content" "DIFF_CONTENT" "$diff_content")

    # Add additional prompt from -p if provided
    if [[ -n "$additional_prompt_text" ]]; then
        commit_prompt="$commit_prompt

Additional instructions: $additional_prompt_text"
    fi

    gum pager "$commit_prompt" --timeout=5s

    log "📨 Generating AI commit message suggestion using configured providers..."
    # query_ai_with_fallback(prompt) - it will use CONFIG_FILE for provider/model/temp
    local suggested_message
    suggested_message=$(query_ai_with_fallback "$commit_prompt")


    if [[ -z "$suggested_message" ]]; then
        error "❌ Failed to generate commit message. Please type your own."
        suggested_message="<commit message template>" # Provide a fallback template
    fi

    echo "$suggested_message" | fold -s -w "$(tput cols)" | gum format --theme=dark

    local extra_context=""
    # Refinement loop
    while [[ -z "$user_context" ]] && gum confirm "Would you like to clarify or refine the commit message?"; do
        local user_addition
        user_addition=$(gum write --placeholder "Add more details or provide refinement instructions..." --width "$(tput cols)" --height 15)

        if [[ -z "$user_addition" ]]; then break; fi # Exit loop if user provides no input

        extra_context="$extra_context
$user_addition" # Append new context

        local refined_prompt="$commit_prompt"
        if [[ -n "$extra_context" ]]; then # Add user clarification if present
            refined_prompt="$refined_prompt

### User Clarification/Refinement:
$extra_context"
        fi
        # Add previous suggestion for context
        refined_prompt="$refined_prompt

### Previous AI Suggestion (for context, do not repeat verbatim):
$suggested_message"

        gum pager "$refined_prompt" --timeout=5s
        log "📨 Refining AI commit message suggestion..."
        suggested_message=$(query_ai_with_fallback "$refined_prompt")

        if [[ -z "$suggested_message" ]]; then
            error "❌ Failed to refine commit message. Using previous or please type your own."
            # Keep the last good suggested_message or prompt user
            if [[ -z "$suggested_message" ]]; then # if it failed and was empty
                 suggested_message="<refinement failed, please edit>"
            fi
        fi
        echo "$suggested_message" | fold -s -w "$(tput cols)" | gum format --theme=dark
    done

    # Final user confirmation and edit
    echo "$suggested_message" | fold -s -w "$(tput cols)" | gum format --theme=dark
    if gum confirm "Proceed with this commit message (you can edit it next)?"; then
        local final_commit_message
        final_commit_message=$(gum write --placeholder "Enter your commit message" --value "$suggested_message" --width "$(tput cols)" --height 15)

        if [[ -z "$final_commit_message" ]]; then
            error "❌ Commit message cannot be empty."
            exit 1
        fi

        git commit -m "$final_commit_message"
        log "✅ Commit successful!"
    else
        log "❌ Commit aborted."
    fi
}

generate_pr_markdown() {
    local base_branch="$1"
    # local text_only_flag="$2" # This was not used in the original function logic for query
    # This is now handled by the TEXT_ONLY variable set by parse_arguments

    if [[ -z "$base_branch" ]]; then
        error "❌ Error: No base branch provided. Usage: pitch pr <base_branch> [--text-only]"
        exit 1
    fi

    get_git_repo_root # Exits if not in a git repo
    export CONFIG_FILE="$git_root/.git/hooks/prepare-commit-msg.properties"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        warn "Project specific config not found at $CONFIG_FILE. Creating default."
        create_default_config "$CONFIG_FILE"
    fi

    local branch_name
    branch_name=$(git rev-parse --abbrev-ref HEAD)

    log "🔍 Comparing $base_branch to $branch_name..."
    local diff_content
    diff_content=$(git diff "$base_branch".."$branch_name" --unified=3 --no-color | tail -n "$(get_config_value "$CONFIG_FILE" "MAX_DIFF_LINES" "500")")


    if [[ -z "$diff_content" ]]; then
        error "❌ No differences found between $base_branch and $branch_name."
        exit 1
    fi

    # PR Body Prompt (from $INSTALL_DIR/pr-description.prompt or default)
    local pr_body_prompt_file="$INSTALL_DIR/pr-description.prompt"
    if [[ ! -f "$pr_body_prompt_file" ]]; then
        error "PR body prompt file not found: $pr_body_prompt_file"
        # Fallback to a very basic prompt if file is missing
        pr_body_prompt_file=$(mktemp)
        echo "Generate a concise PR description in Markdown format for the following Git diff:
\$DIFF_CONTENT" > "$pr_body_prompt_file"
    fi
    local pr_body_base_prompt=$(cat "$pr_body_prompt_file")
    local pr_body_final_prompt=$(replace_template_values "$pr_body_base_prompt" "DIFF_CONTENT" "$diff_content")

    log "📨 Generating PR description..."
    local pr_body
    pr_body=$(query_ai_with_fallback "$pr_body_final_prompt")
    if [[ -z "$pr_body" ]]; then
        error "Failed to generate PR body. Using a placeholder."
        pr_body="## 📌 Summary
<AI failed to generate summary. Please fill this manually.>

## 🔄 Changes Made
- ...

## 🛠 How to Test
1. ..."
    fi

    # PR Title Prompt (from $INSTALL_DIR/pr-title.prompt or default)
    local pr_title_prompt_file="$INSTALL_DIR/pr-title.prompt"
     if [[ ! -f "$pr_title_prompt_file" ]]; then
        error "PR title prompt file not found: $pr_title_prompt_file"
        pr_title_prompt_file=$(mktemp)
        # DIFF_CONTENT and PR_BODY are available as template values
        echo "Generate a concise Pull Request title based on the following diff:
\$DIFF_CONTENT

And the PR body:
\$PR_BODY" > "$pr_title_prompt_file"
    fi
    local pr_title_base_prompt=$(cat "$pr_title_prompt_file")
    local pr_title_final_prompt=$(replace_template_values "$pr_title_base_prompt" "DIFF_CONTENT" "$diff_content")
    pr_title_final_prompt=$(replace_template_values "$pr_title_final_prompt" "PR_BODY" "$pr_body")


    log "📨 Generating PR title..."
    local pr_title
    pr_title=$(query_ai_with_fallback "$pr_title_final_prompt")
    if [[ -z "$pr_title" ]]; then
        error "Failed to generate PR title. Using a placeholder."
        pr_title="[AI Failed] Review changes for $branch_name"
    fi
    
    local formatted_pr
    formatted_pr=$(echo -e "# $pr_title\n\n$pr_body" | gum format --theme=dark)
    echo "$formatted_pr"

    if command -v gh >/dev/null 2>&1 && [[ "$TEXT_ONLY" != "true" ]]; then
        if gum confirm "🔗 Create GitHub Pull Request with these details?"; then
            gh pr create --base "$base_branch" --head "$branch_name" --title "$pr_title" --body "$pr_body"
        else
            log "Skipping GitHub PR creation as per user choice."
        fi
    else
        log "ℹ️ Skipping GitHub PR creation (either --text-only flag is set, gh CLI is missing, or user declined)."
    fi
}


generate_readme() {
    get_git_repo_root # Exits if not in a git repo
    export CONFIG_FILE="$git_root/.git/hooks/prepare-commit-msg.properties"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        warn "Project specific config not found at $CONFIG_FILE. Creating default."
        create_default_config "$CONFIG_FILE"
    fi

    local project_files
    local ignore_pattern=""
    local ignored_paths_default=("*/.git/*" "*/node_modules/*" "*/vendor/*" "*/dist/*" "*/build/*" "*/target/*" "*.lock" "*.log")
    local ignored_paths_user_str="" # For --ignore flag
    
    # Parse --ignore argument if provided for generate_readme
    # Note: parse_arguments only handles global flags. Local flags need local parsing.
    # This is a simplified local parsing for this function.
    local temp_args=()
    for arg in "$@"; do
        if [[ "$arg" == --ignore=* ]]; then
            ignored_paths_user_str="${arg#--ignore=}"
        else
            temp_args+=("$arg") # Keep other args if any, though generate_readme doesn't expect others
        fi
    done
    # set -- "${temp_args[@]}" # Reset positional parameters if needed, not necessary here

    local all_ignored_paths=("${ignored_paths_default[@]}")
    if [[ -n "$ignored_paths_user_str" ]]; then
        IFS=',' read -ra user_ignores <<< "$ignored_paths_user_str"
        all_ignored_paths+=("${user_ignores[@]}")
    fi

    log "📂 Collecting project files..."
    log "🚫 Ignoring paths: ${all_ignored_paths[*]}"

    # Construct find command arguments for ignored paths
    local find_ignore_args=()
    for pattern in "${all_ignored_paths[@]}"; do
        find_ignore_args+=(\! -path "$pattern")
    done

    # Find files, ensuring we are in the git_root directory for find . to work correctly
    pushd "$git_root" > /dev/null
    project_files=$(find . -type f \( "${find_ignore_args[@]}" \) -print0 | xargs -0 realpath 2>/dev/null)
    popd > /dev/null


    if [[ -z "$project_files" ]]; then
        error "❌ No relevant project files found to generate README."
        exit 1
    fi

    local aggregated_summary=""
    log "📄 Summarizing project files using configured AI..."
    for file_path in $project_files; do
        if [[ ! -f "$file_path" ]]; then continue; fi # Skip if not a file (e.g. from bad realpath output)
        log "🔍 Processing $file_path..."
        local file_content
        file_content=$(cat "$file_path")
        if [[ -z "$file_content" ]]; then
            log "Skipping empty file: $file_path"
            continue
        fi

        # Truncate very large files to avoid excessive API usage / costs
        local max_file_chars=10000
        if [[ "${#file_content}" -gt "$max_file_chars" ]]; then
            file_content="${file_content:0:$max_file_chars}..."
            log "Truncated $file_path to $max_file_chars characters for summary."
        fi

        # Define a prompt for summarizing a single file
        local single_file_summary_prompt="Analyze the following file and extract:
- A concise summary of its purpose.
- A list of defined functions or main components.
- Any key configurations or settings if apparent.

File: $(basename "$file_path")
Content:
$file_content

Output format:
SUMMARY: <summary of the file>
COMPONENTS: <list of functions/components or N/A>
CONFIGURATIONS: <list of key configurations or N/A>"

        local file_summary
        file_summary=$(query_ai_with_fallback "$single_file_summary_prompt")

        if [[ -n "$file_summary" ]]; then
            aggregated_summary+="File: $(basename "$file_path")
${file_summary}

---

"
        else
            log "Could not summarize file: $file_path"
        fi
    done

    if [[ -z "$aggregated_summary" ]]; then
        error "❌ Failed to summarize any project files. Cannot generate README."
        exit 1
    fi

    log "📨 Sending aggregated summaries for final README generation..."
    local readme_generation_prompt="Generate a comprehensive README.md file based on the following project file summaries:

${aggregated_summary}

Guidelines:
- Include an Introduction explaining what the project does.
- Describe key components, functions, and configurations based on the summaries.
- Provide basic installation and usage instructions if possible to infer, otherwise suggest placeholders.
- Format everything strictly in Markdown.

Output the README.md content only, without additional explanations or preamble."

    local readme_content
    readme_content=$(query_ai_with_fallback "$readme_generation_prompt")

    if [[ -z "$readme_content" ]]; then
        error "❌ Failed to generate README content."
        exit 1
    fi

    log "📄 Writing README.md to $git_root/README.md..."
    echo -e "$readme_content" > "$git_root/README.md" # Use -e for potential newlines in readme_content

    log "✅ README.md successfully generated!"
}


# ───────────────────────────────────────────────────────────
# 🔹 SCRIPT EXECUTION LOGIC (Main case statement)
# ───────────────────────────────────────────────────────────
# (install_gum, install_git_hook, register_symlink, update_pitch, info, show_help remain largely the same)
# (The 'install' case in main.sh calls functions from model.sh like install_ollama, create_model. These are Ollama specific.)
# (The 'model' case calls pitch_model from lib/model.sh, which will be updated in a later step)

# Ensure gum is installed early as it's used by many functions
install_gum

# Set CONFIG_FILE globally for any function that might need it,
# especially those from external libraries that don't explicitly get it passed.
# For commands run inside a repo (commit, pr, readme), CONFIG_FILE will be reset to project specific.
export CONFIG_FILE
CONFIG_FILE=$(get_active_config_file)


case "$1" in
    help|-h|--help)
        show_help # show_help needs to be updated for new provider commands
        ;;
    install)
        # This 'install' is the main.sh internal one, not install.sh script itself.
        # It sets up Ollama and Ollama models.
        # This part might need to be re-evaluated if Ollama is not the primary/default.
        # For now, assume it installs Ollama as one of the available providers.
        log "Running internal setup (Ollama, default models)..."
        install_ollama # From model.sh (Ollama specific)
        start_ollama   # From model.sh (Ollama specific)
        # register_symlink is typically done by install.sh script. Redundant?
        # create_model calls 'ollama create', so it's Ollama specific.
        # These default models are Ollama-specific.
        create_model "llama3.1:latest" # Creates pitch_llama3.1:latest
        # create_model "deepseek-coder:latest" # Creates pitch_deepseek-coder:latest
        log "Default Ollama models (if not existing) have been processed."
        log "To configure other providers (OpenAI, Claude), ensure API keys are set up."
        log "You might have already configured them during the 'install.sh' script execution."
        ;;
    uninstall)
        # This should also be provider-aware if it needs to clean up API keys etc.
        # For now, it's mostly Ollama focused.
        remove_pitch_models # Removes 'pitch_*' ollama models
        stop_ollama
        # uninstall_ollama # This function doesn't exist in model.sh, original used 'uninstall' from main.sh
        # The main uninstall function in original main.sh (for 'pitch uninstall')
        # rm -rf "$MODEL_DIR", unlink "$HOME/.local/bin/pitch", brew uninstall ollama, rm -rf "$INSTALL_DIR"
        # This needs to be a separate function if called here.
        log "Uninstalling Ollama-specific parts..."
        # Call a more comprehensive uninstall if needed.
        log "Full uninstallation should be done via the uninstall script if one is provided, or manually."
        ;;
    # delete, start, stop, info, apply, update, create_model cases largely unchanged for now,
    # but 'info' and 'model' will need updates.
    delete) # Deletes ollama models
        delete_models # from model.sh
        log "Ollama models deletion complete."
        ;;
    start) # Starts ollama
        start_ollama # from model.sh
        ;;
    stop) # Stops ollama
        stop_ollama # from model.sh
        ;;
    info)
        # Needs significant update to show multi-provider status
        info # Original info function
        # TODO: Call show_provider_status from model.sh (to be created)
        ;;
    apply)
        install_git_hook # This copies prepare-commit-msg.sh and .properties
        # Ensure the .properties file copied is the new multi-provider one.
        # install_git_hook should copy $INSTALL_DIR/prepare-commit-msg.properties as a template.
        # And then potentially run migrate_legacy_config on it if it was an old one.
        # Or, create_default_config if it doesn't exist in the project.
        git_root_apply=$(get_git_repo_root)
        if [[ -n "$git_root_apply" ]]; then
            project_config_to_apply="$git_root_apply/.git/hooks/prepare-commit-msg.properties"
            if [[ ! -f "$project_config_to_apply" ]]; then
                log "Creating default config in project: $project_config_to_apply"
                create_default_config "$project_config_to_apply"
            else
                log "Project config $project_config_to_apply already exists. Checking for migration..."
                # migrate_legacy_config will only run if it's actually a legacy format.
                # This requires migrate_legacy_config to be robust.
                # It's better if install_git_hook copies the NEW template, always.
                # For now, let's assume install_git_hook copies the template from $INSTALL_DIR/prepare-commit-msg.properties
                # which should be the new version.
            fi
        fi
        ;;
    commit)
        # Shift off 'commit' itself from arguments before passing to the function
        shift
        commit "$@" # Pass remaining args like -m, -p
        ;;
    model)
        # This will call pitch_model from lib/model.sh, which is the next plan step to update.
        pitch_model
        ;;
    update)
        update_pitch
        ;;
    create_model) # This is Ollama specific
        if [[ -z "$2" ]]; then error "Model name required for create_model."; exit 1; fi
        create_model "$2" # from model.sh
        ;;
    pr)
        # Shift off 'pr' itself
        shift
        generate_pr_markdown "$@" # Pass base_branch and any flags like --text-only
        ;;
    readme)
        shift
        generate_readme "$@" # Pass --ignore flags
        ;;
    ask)
        shift
        ask "$@" # Pass user input
        ;;
    # New command for provider status
    providers)
        # This function will be added to lib/model.sh
        show_provider_status
        ;;
    *)
        show_help
        exit 1
        ;;
esac