#!/bin/bash

SCRIPT_DIR="$HOME/.ollama-git-pitch-gen"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/model.sh"
source "$SCRIPT_DIR/lib/git.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# ───────────────────────────────────────────────────────────
# 🔹 GLOBAL VARIABLES
# ───────────────────────────────────────────────────────────
MODEL_NAME="lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF"  # Replace with your Hugging Face model name
HUGGINGFACE_URL="https://huggingface.co/lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF"  # Model URL
MODEL_DIR="$HOME/models"  # Directory to store the model
MODEL_PATH="pitch_llama3.1:latest"  # Model alias for Ollama
SYSTEM_PROMPT="You are an AI expert in answering questions accurately."
CONFIG_FILE=".git/prepare-commit-msg.properties"
INSTALL_DIR="$HOME/.ollama-git-pitch-gen"
DISABLE_LOGS="true"

parse_arguments "$@"

ask() {
    # Use provided argument as user input if available, otherwise prompt
    local user_input="$1"
    if [[ -z "$user_input" ]]; then
        user_input=$(gum input --placeholder "Ask something..." --width "$(tput cols)")
    fi

    # Allow user to select models using gum checkbox
    selected_models=$(ollama list | awk '{print $1}' | tail -n +2 | gum choose --no-limit)

    # Convert selected_models into an array (compatible with older Bash versions)
    IFS=$'\n' read -rd '' -a selected_models <<< "$selected_models"

    # Validate selection
    if [[ ${#selected_models[@]} -eq 0 ]]; then
        echo "❌ No models selected. Exiting..."
        return 1
    fi

    # Get terminal width and divide it by the number of selected models
    total_width=$(tput cols)
    model_count=${#selected_models[@]}
    
    # Prevent division by zero
    if [[ "$model_count" -eq 0 ]]; then
        echo "❌ No models selected. Exiting..."
        return 1
    fi
    
    box_width=$(( total_width / model_count - 4 ))  # Adjust width dynamically

    # Initialize arrays to store responses and boxes
    responses=()  # Using indexed array instead of associative array
    boxes=()

    # Query each selected model
    for model in "${selected_models[@]}"; do
        response=$(ollama run "$model" "$user_input")
        responses+=("$response")
    done

    # Create styled boxes for each response
    index=0
    for model in "${selected_models[@]}"; do
        formatted_response=$(echo "**🤖 $model Response:** ${responses[$index]}" | gum format --theme=dark)
        box=$(gum style --border double --width "$box_width" --align left --padding "1 2" "$formatted_response")
        boxes+=("$box")
        ((index++))
    done

    # Display boxes side by side
    gum join --align center "${boxes[@]}"
}




# ───────────────────────────────────────────────────────────
# 🔹 INSTALLATION FUNCTIONS
# ───────────────────────────────────────────────────────────
install_git_hook() {
    git_root=$(get_git_repo_root)

    local hooks_dir="$git_root/.git/hooks"
    local hook_file="$hooks_dir/prepare-commit-msg"
    local script_dir
    script_dir=$(dirname "$(realpath "$0")")

    local hook_source="$script_dir/prepare-commit-msg.sh"
    local hook_properties="$script_dir/prepare-commit-msg.properties"
    
    local commit_prompt="$script_dir/commit.prompt"
    local pr_title_prompt="$script_dir/pr-title.prompt"
    local pr_body_prompt="$script_dir/pr-description.prompt"

    if [[ ! -f "$hook_source" ]]; then
        error "Hook script '$hook_source' not found."
    fi

    log "Installing Git hook..."
    cp "$hook_source" "$hook_file"
    cp "$hook_properties" "$hook_file.properties"

    cp "$commit_prompt" "$hooks_dir/commit.prompt"
    cp "$pr_title_prompt" "$hooks_dir/pr-title.prompt"
    cp "$pr_body_prompt" "$hooks_dir/pr-description.prompt"

    chmod +x "$hook_file"

    log "Git hook installed successfully."
    log "$hook_file"
    log "$hook_file.properties"
    log "$hooks_dir.commit.prompt"
    log "$hooks_dir.pr-title.prompt"
    log "$hooks_dir.pr-description.prompt"
}

register_symlink() {
    local target="$HOME/.local/bin/pitch"
    mkdir -p "$HOME/.local/bin"

    if [[ -L "$target" ]]; then
        log "Symlink already exists at $target."
    else
        log "Creating symlink: $target -> $PWD/main.sh"
        ln -s "$PWD/main.sh" "$target"
        chmod +x "$target"
    fi
}

update_pitch() {
    echo "🔄 Checking for updates..."
    INSTALL_DIR="$HOME/.ollama-git-pitch-gen"
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo "❌ Installation directory not found. Please reinstall using the install script."
        exit 1
    fi

    cd "$INSTALL_DIR"
    git fetch origin main
    latest_local_commit=$(git rev-parse HEAD)
    latest_remote_commit=$(git rev-parse origin/main)

    if [[ "$latest_local_commit" == "$latest_remote_commit" ]]; then
        echo "✅ You are already up to date!"
    else
        echo "⬆️ Updating to the latest version..."
        git pull origin main
        echo "🎉 Update complete! Run 'pitch info' to verify the latest version."
    fi
}

# ───────────────────────────────────────────────────────────
# 🔹 MAIN FUNCTIONS
# ───────────────────────────────────────────────────────────
info() {
    log "Gathering system and installation information..."

    local markdown_output=""

    markdown_output+=$'\n**🖥️   OS:** '"$(uname -a)"$''
    markdown_output+=$'\n**💻  Shell:** '"$SHELL"$''

    log "Checking if Ollama is installed..."
    if command -v ollama >/dev/null 2>&1; then
        markdown_output+=$'\n✅ **Ollama installed:** '"$(ollama --version)"$''
    else
        markdown_output+=$'\n❌ **Ollama is NOT installed.**'
    fi

    log "Checking if Ollama server is running..."
    if pgrep -f "ollama serve" >/dev/null; then
        markdown_output+=$'\n✅ **Ollama server is running.**'
    else
        markdown_output+=$'\n❌ **Ollama server is NOT running.**'
    fi

    log "Listing available Ollama models..."
    markdown_output+=$'\n📦 **Available Models:**'
    models=$(ollama list 2>/dev/null | grep -v "GIN")
    if [[ -n "$models" ]]; then
        markdown_output+="$models\n"
    else
        markdown_output+=$'\n❌ **No models found.**'
    fi

    log "Checking if inside a Git repository..."
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$git_root" ]]; then
        log "Git repository detected at: $git_root"
        hook_path="$git_root/.git/hooks/prepare-commit-msg"
        config_file="$git_root/.git/hooks/prepare-commit-msg.properties"

        log "Checking Git hooks..."
        if [[ -f "$hook_path" ]]; then
            markdown_output+=$'\n✅ **Git hook installed at:** '"$hook_path"$''
        else
            markdown_output+=$'\n❌ **Git hook NOT installed.**'
        fi

        log "Checking commit message configuration..."
        if [[ -f "$config_file" ]]; then
            model_name=$(grep "^OLLAMA_MODEL=" "$config_file" | cut -d '=' -f2)
            if [[ -n "$model_name" ]]; then
                markdown_output+=$'\n🤖 **Current AI Model:** '"$model_name"$''
            else
                markdown_output+=$'\n❌ **No model set in $config_file.**'
            fi
        else
            markdown_output+=$'\n❌ **Configuration file not found:** '"$config_file"$''
        fi
    else
        markdown_output+=$'\n❌ **Not inside a Git repository.**'
    fi

    log "Checking symlink for pitch executable..."
    symlink_target="$HOME/.local/bin/pitch"
    if [[ -L "$symlink_target" ]]; then
        markdown_output+=$'\n🔗 **Symlink for pitch is set up at:** '"$(readlink -f "$symlink_target")"$''
    else
        markdown_output+=$'\n❌ **Symlink for pitch is NOT set up.**'
    fi

    log "Checking latest commit hash..."
    install_dir="$HOME/.ollama-git-pitch-gen"
    if [[ -d "$install_dir" ]]; then
        cd "$install_dir"
        latest_local_commit=$(git rev-parse HEAD)
        latest_remote_commit=$(git ls-remote origin -h refs/heads/main | awk '{print $1}')

        markdown_output+=$'\n🔍 Latest installed commit: '"$latest_local_commit"$''
        if [[ "$latest_local_commit" != "$latest_remote_commit" ]]; then
            markdown_output+=$'\n⚠️  A new update is available. Run \'pitch update\' to get the latest version.'
        else
            markdown_output+=$'\n✅ **Your installation is up to date.**'
        fi
    else
        markdown_output+=$'\n❌ **Installation directory not found:** '"$install_dir"$''
    fi

    # Render the markdown output at the end
    echo -e "$markdown_output" | gum format --theme=dark
}

commit() {
    local user_context=""
    local additional_prompt=""
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -m)
                user_context="$2"
                shift 2
                ;;
            -p)
                additional_prompt="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    get_git_repo_root

    local diff_content=$(git diff --cached --unified=0 --no-color | tail -n 100)

    if [[ -z "$diff_content" ]]; then
        echo "❌ No staged changes found. Please stage files before committing."
        exit 1
    fi

    local config_file=".git/hooks/prepare-commit-msg.properties"
    local local_model=$MODEL_PATH
    if [[ -f "$config_file" ]]; then
        local_model=$(grep "^OLLAMA_MODEL=" "$config_file" | cut -d '=' -f2-)
    fi

    # Check if the model exists
    check_model_exists "$local_model"

    local prompt_file=".git/hooks/commit.prompt"
    if [[ ! -f "$prompt_file" ]]; then
        echo "❌ Commit prompt file not found at $prompt_file"
        exit 1
    fi

    local prompt_content=$(cat "$prompt_file")
    local commit_prompt=$(replace_template_values "$prompt_content" "DIFF_CONTENT" "$diff_content")
    gum pager "$commit_prompt" --timeout=5s

    echo "📨 Generating AI commit message suggestion..."
    local suggested_message=$(ollama run "$local_model" "$commit_prompt. $diff_content Format output as: <commit message>")

    if [[ -z "$suggested_message" ]]; then
        echo "❌ Failed to generate commit message. Please type your own."
        suggested_message=""
    fi

    echo "$suggested_message" | fold -s -w "$(tput cols)" | gum format --theme=dark
    # If user did not provide -m, ask if they want to clarify
    local extra_context=""
    while [[ -z "$user_context" ]] && gum confirm "Would you like to clarify the commit message by providing more context?"; do
        user_addition=$(gum write --placeholder "Add more details about this commit" --width "$(tput cols)" --height 15)

        # Append the new user context while keeping previous suggestions
        extra_context="$extra_context\n$user_addition"

        # Prepare refined commit prompt
        commit_prompt="
            $commit_prompt
            ### User Clarification:
            $extra_context
        "
        commit_prompt="
            $commit_prompt
            ### Previous Suggestion:
            $suggested_message
        "
        gum pager "$commit_prompt" --timeout=5s

        echo "📨 Refining AI commit message suggestion..."
        suggested_message=$(ollama run "$local_model" "$commit_prompt")

        # Display refined commit message
        echo "$suggested_message" | fold -s -w "$(tput cols)" | gum format --theme=dark
    done


    # Final user confirmation
    echo "$suggested_message" | fold -s -w "$(tput cols)" | gum format --theme=dark
    if gum confirm "Would you like to proceed with this commit message?"; then
        # Use Gum to allow user to make final edits
        local commit_message=$(gum write --placeholder "Enter your commit message" --value "$suggested_message" --width "$(tput cols)" --height 15)

        # Ensure commit message is not empty
        if [[ -z "$commit_message" ]]; then
            echo "❌ Commit message cannot be empty."
            exit 1
        fi

        # Commit with the final message
        git commit -m "$commit_message"
        echo "✅ Commit successful!"
    else
        echo "❌ Commit aborted."
    fi
}

generate_pr_markdown() {
    local base_branch="$1"
    local text_only_flag="$2"
    local branch_name
    local diff_content
    local model_name
    local config_file=".git/hooks/prepare-commit-msg.properties"

    # Validate that base_branch is provided
    if [[ -z "$base_branch" ]]; then
        echo "❌ Error: No base branch provided."
        echo "Usage: pitch pr <base_branch> [--text-only]"
        echo "Example: pitch pr main"
        exit 1
    fi

    # Get the current Git branch name
    branch_name=$(git rev-parse --abbrev-ref HEAD)

    # Get the AI model from the properties file
    if [[ -f "$config_file" ]]; then
        model_name=$(grep "^OLLAMA_MODEL=" "$config_file" | cut -d '=' -f2)
    else
        model_name="pitch_default"  # Default fallback model
    fi

    echo "🤖 Using AI Model: $model_name"

    # Get the Git diff between base branch and the current branch
    echo "🔍 Comparing $base_branch to $branch_name..."
    diff_content=$(git diff "$base_branch".."$branch_name" --unified=3 --no-color | tail -n 100)

    if [[ -z "$diff_content" ]]; then
        echo "❌ No differences found between $base_branch and $branch_name."
        exit 1
    fi

    if [[ -z "$pr_title" ]]; then
        pr_title="Auto-generated PR Title"
    fi

    # Get PR description from Ollama
    echo "📨 Generating PR description..."
    local pr_body_prompt="
    ### Instruction:
    Do not include an introduction, preface, or explanation. Respond only with the PR description.
    
    ### Task:
    Generate a concise PR description in Markdown format for the following Git diff:
        $diff_content

        Format output as:
        ## 📌 Summary
        <PR Summary>

        ## 🔄 Changes Made
        - List modified files

        ## 🛠 How to Test
        1. Steps to validate the changes

        ## ✅ Checklist
        - [ ] Code follows project guidelines
        - [ ] Tests have been added/updated
        - [ ] Documentation is updated if needed
    "
    pr_body=$(ollama run "$model_name" "$pr_body_prompt")

    # Get PR title from Ollama
    echo "📨 Generating PR title..."
    local pr_title_prompt="
    ### Instruction:
    Do not include an introduction, preface, or explanation. Respond only with the PR title.

    ### Task:
    Generate a concise Pull Request title based on the following:
     - diff: $diff_content:
     - description: $pr_body

    Respond with only the PR title."
    pr_title=$(ollama run "$model_name" "$pr_title_prompt")

    # Format the PR message using gum
    formatted_pr=$(echo -e "# $pr_title\n\n$pr_body" | gum format --theme=dark)

    # Display formatted PR message
    echo "$formatted_pr"

    # Check if GitHub CLI is installed and --text-only flag is NOT provided
    if command -v gh >/dev/null 2>&1 && [[ "$TEXT_ONLY" != "true" ]]; then
        echo "🔗 Creating GitHub Pull Request..."
        gh pr create --base "$base_branch" --head "$branch_name" --title "$pr_title" --body "$pr_body"
    else
        echo "ℹ️ Skipping GitHub PR creation (either --text-only flag is set or gh CLI is missing)."
    fi
}

generate_readme() {
    local model_name
    local project_files
    local aggregated_summary=""
    local readme_content
    local ignore_pattern=""
    local ignored_paths=("*/.git/*" "*/node_modules/*" "*/vendor/*" "*/dist/*" "*/build/*", "*/target/*")
    local config_file
    
    git_root=$(get_git_repo_root)

    config_file="$git_root/.git/hooks/prepare-commit-msg.properties"
    echo "config_file: $config_file"

    # Get the AI model from the properties file
    if [[ -f "$config_file" ]]; then
        model_name=$(grep "^OLLAMA_MODEL=" "$config_file" | cut -d '=' -f2)
    else
        model_name="pitch_readme_generator"  # Default fallback model
    fi
    # Check for ignore pattern in arguments
    for arg in "$@"; do
        if [[ "$arg" == --ignore=* ]]; then
            extra_ignore_pattern="${arg#--ignore=}"  # Extract pattern after --ignore=
            ignored_paths+=($extra_ignore_pattern)
        fi
    done

    echo "📂 Collecting project files..."
    echo "🚫 Ignoring paths: ${ignored_paths[*]}"
    project_files=$(find . -maxdepth 10 \( $(printf "! -path %s " "${ignored_paths[@]}") \) -type f -exec realpath {} \;)

    if [[ -z "$project_files" ]]; then
        echo "❌ No relevant project files found to generate README."
        exit 1
    fi

    echo "📄 Summarizing project files ($model_name)..."
    for file in $project_files; do
        echo "🔍 Processing $file..."
        file_content=$(cat "$file")
        file_summary=$(ollama run "$model_name" "Analyze the following file and extract:
- A concise summary of its purpose.
- A list of defined functions, including their names and arguments.
- Any key configurations or settings.

File: $file
Content:
$file_content

Output format:
SUMMARY: <summary of the file>
FUNCTIONS:
- function_name1(arg1, arg2)
- function_name2(arg1, arg2)

CONFIGURATIONS:
- Key1: Value1
- Key2: Value2")

        aggregated_summary+="$file_summary\n\n"
    done

    echo "📨 Sending aggregated summaries to Ollama for README generation..."
    readme_content=$(ollama run "$model_name" "Generate a comprehensive README.md file based on the following project summaries:

$aggregated_summary

Guidelines:
- Include an Introduction explaining what the project does.
- Describe all detected functions and configurations.
- Provide installation and usage instructions.
- Format everything strictly in Markdown.

Output the README.md content only, without additional explanations.")

    if [[ -z "$readme_content" ]]; then
        echo "❌ Failed to generate README."
        exit 1
    fi

    echo "📄 Writing README.md..."
    echo "$readme_content" > README.md

    echo "✅ README.md successfully generated!"
}

# ───────────────────────────────────────────────────────────
# 🔹 SCRIPT EXECUTION LOGIC
# ───────────────────────────────────────────────────────────

# Add help function with detailed command descriptions
show_help() {
    cat << EOF
Usage: pitch <command> [options]

Commands:
    install         Install Ollama and setup the environment
    uninstall      Remove Ollama and clean up
    start          Start Ollama server
    stop           Stop Ollama server
    info           Display system information
    apply          Install Git hooks
    commit         Generate AI-powered commit message
    model          Select AI model
    update         Update pitch to latest version
    pr             Generate pull request
    readme         Generate README.md

Options:
    --debug        Enable debug logging
    --no-logs      Disable logging
    --config=FILE  Use specific config file

Examples:
    pitch install
    pitch commit -m "feat: add new feature"
    pitch pr main --text-only
EOF
    exit 0
}

case "$1" in
    help|-h|--help)
        show_help
        ;;
    install)
        install_ollama
        start_ollama
        register_symlink
        create_model llama3.2
        create_model llama3.1:latest
        create_model deepseek-coder:latest
        ;;
    uninstall)
        remove_pitch_models
        stop_ollama
        uninstall
        log "Uninstallation complete."
        ;;
    delete)
        delete_models
        log "Uninstallation complete."
        ;;
    start)
        start_ollama
        ;;
    stop)
        stop_ollama
        ;;
    info)
        info
        ;;
    apply)
        install_git_hook
        ;;
    commit)
        commit
        ;;
    model)
        pitch_model
        ;;
    update)
        update_pitch
        ;;
    create_model)
        create_model $2
        ;;
    pr)
        generate_pr_markdown $2
        ;;
    readme)
        generate_readme
        ;;
    ask)
        ask "$2"
        ;;
    *)
        show_help
        exit 1
        ;;
esac