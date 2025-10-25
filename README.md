# Git Pitch Generator Tool
==========================

## Introduction
---------------

The `git-pitch-gen` tool is a CLI application that integrates with Ollama to generate meaningful commit messages and pull request descriptions using AI. It aims to streamline your Git workflow by automating the creation of well-formatted and descriptive messages.

## Installation
--------------

To install the tool, run the following command in your terminal. This script will attempt to install Ollama if not already present, set up necessary configurations, and make the `pitch` command available system-wide.

```bash
curl -fsSL https://raw.githubusercontent.com/guilhermehbueno/ollama-git-pitch-gen/master/install.sh | bash
```
Follow any on-screen prompts during the installation.

## Usage
-----

Once installed, you can use the `pitch` command from any Git repository.

A common workflow involves:
1.  Staging your changes (`git add .`).
2.  Running `pitch commit` to let the AI generate a commit message for you.
3.  If you work with pull requests, after pushing your branch, run `pitch pr <target-branch>` to generate a title and description for your PR.

For more specific actions like managing models, starting/stopping the Ollama server, or updating the tool, refer to the commands below.

## Command Reference
-------------------

All commands are invoked using the `pitch` executable.

*   **`pitch install`**
    *   **Purpose:** Performs the initial installation of the `git-pitch-gen` tool.
    *   **Details:** This command installs Ollama (if not already present and configured), starts the Ollama server, registers a system-wide symlink for the `pitch` command, and creates default AI models required for the tool to function. It's typically run once.

*   **`pitch readme`**
    *   **Purpose:** Displays this README documentation directly in the terminal.
    *   **Details:** Useful for quick reference of commands, configurations, and other information without leaving your terminal.

*   **`pitch uninstall`**
    *   **Purpose:** Completely removes the `git-pitch-gen` tool and its configurations.
    *   **Details:** This includes deleting any `pitch_*` models from Ollama, stopping the Ollama server (if started by `pitch`), removing the `pitch` symlink, and deleting the configuration directory (`~/.ollama-git-pitch-gen`).

*   **`pitch delete`**
    *   **Purpose:** Deletes only the `pitch_*` AI models from Ollama.
    *   **Details:** This command is useful if you want to free up space or reset the models without uninstalling the entire tool. The rest of the installation (symlink, configuration files) remains intact.

*   **`pitch start`**
    *   **Purpose:** Starts the Ollama server.
    *   **Details:** Ensures the Ollama server is running, which is necessary for AI model interactions. The `install` command typically starts the server, but this can be used to manually restart it.

*   **`pitch stop`**
    *   **Purpose:** Stops the Ollama server.
    *   **Details:** Shuts down the Ollama server. This is useful if you need to stop the server process manually.

*   **`pitch info`**
    *   **Purpose:** Displays system information relevant to the `git-pitch-gen` tool.
    *   **Details:** This includes information about installed `pitch_*` models, the status of symlinks, available updates for the tool, and other diagnostic details.

*   **`pitch apply`**
    *   **Purpose:** Installs or re-installs the Git hook for automatic commit message generation.
    *   **Details:** This command sets up the `prepare-commit-msg` Git hook in the current Git repository. When you run `git commit`, this hook will trigger `pitch commit` to generate a message.

*   **`pitch model`**
    *   **Purpose:** Allows the user to switch the active AI model used for generating messages.
    *   **Details:** It lists available `pitch_*` models (e.g., by running `ollama list` and filtering) and prompts the user to select one. The selected model's name is then saved to the `OLLAMA_MODEL` property in the `~/.ollama-git-pitch-gen/prepare-commit-msg.properties` configuration file.

*   **`pitch update`**
    *   **Purpose:** Updates `pitch` to the latest version from the GitHub repository.
    *   **Details:** Fetches the newest version of the scripts and updates your local installation.

*   **`pitch create_model <model-name>`**
    *   **Purpose:** Creates a new custom Ollama model for use with `pitch`.
    *   **Details:** This command interactively prompts the user to select a base model (from available Ollama models) and provide a custom system prompt. It then generates a Modelfile (e.g., `FROM <base_model>\nSYSTEM <user_prompt>`) and uses `ollama create pitch_<model-name> -f <generated_modelfile>` to build and register the new model. The model will be named `pitch_<model-name>:latest`. This allows for tailored AI behavior.

*   **`pitch pr <base_branch>`**
    *   **Purpose:** Generates a Pull Request (PR) title and description using AI.
    *   **Arguments:**
        *   `<base_branch>`: The target branch into which the current branch will be merged (e.g., `main`, `develop`).
    *   **Details:** Compares the changes between the current branch and the specified `<base_branch>`. It then uses the AI model to generate a succinct title and a more detailed description suitable for a pull request. The output is displayed in the terminal for you to copy.

*   **`pitch dev-mode <path>`**
    *   **Purpose:** Temporarily point the `pitch` executable at a local checkout for development.
    *   **Details:** Updates the symlink at `~/.local/bin/pitch` to the `main.sh` inside `<path>`. After running it, invoke commands with `DEV_MODE=1` (for example, `DEV_MODE=1 pitch info`) so the CLI sources everything from your working tree. Re-run `pitch dev-mode` with the original installation directory—or simply reinstall—to restore the released version.

*   **`pitch commit`**
    *   **Purpose:** Generates a commit message using AI based on staged Git changes.
    *   **Details:** Analyzes the `git diff --staged` output and uses the configured AI model and prompt to generate a descriptive commit message. How this message is used depends on the Git hook: if `ALLOW_COMMIT_OVERRIDE=true` (the default), the message will populate the commit editor; if `false`, it will be added as a comment.

## Configuration
-------------

The behavior of `git-pitch-gen` can be customized via a properties file located at `~/.ollama-git-pitch-gen/prepare-commit-msg.properties`.

| Configuration         | Default Value | Description                                                                                                |
| --------------------- | ------------- | ---------------------------------------------------------------------------------------------------------- |
| `OLLAMA_MODEL`        | "DeepSeek"    | The AI model to use for generating messages (e.g., `pitch_mycustommodel:latest`).                            |
| `UNIFIED_LINES`       | 50            | Maximum number of diff lines to process for context (a smaller part of `MAX_DIFF_LINES`).                |
| `ALLOW_COMMIT_OVERRIDE` | true          | If `false`, the AI-generated message is added as a comment in your commit editor instead of overriding it. |
| `OLLAMA_PROMPT`       | ""            | Custom base prompt to use with the AI model. The actual diff will be appended to this prompt.             |
| `MAX_DIFF_LINES`      | 500           | Maximum number of raw diff lines to send to the AI for analysis.                                         |

**Example properties file:**
```properties
# Use a different Ollama model
OLLAMA_MODEL=pitch_llama3_custom:latest

# Custom AI prompt
OLLAMA_PROMPT=As an expert Git user, write a concise commit message for the following changes. Focus on the 'why' not just the 'what':

# Increase max diff lines limit
MAX_DIFF_LINES=1000

# Allow commit override (if false, AI-generated message is appended as a comment)
ALLOW_COMMIT_OVERRIDE=false
```

## Git Hook Integration
-------------------

The `git-pitch-gen` tool primarily leverages a Git hook (`prepare-commit-msg`) to integrate seamlessly into your workflow.

When you run `git commit` in a repository where the hook is active (installed via `pitch apply`):
1.  The hook script reads your configuration from the properties file.
2.  It checks if the Ollama server is running.
3.  It analyzes the staged changes (`git diff --staged`).
4.  It then calls the AI model to generate a commit message.
5.  Depending on the `ALLOW_COMMIT_OVERRIDE` setting, the generated message either populates your commit editor directly or is added as a comment for your reference.

You can install the Git hook in your current Git repository using:
```bash
pitch apply
```
To apply it to all future repositories by default, you can configure Git's global hook template path.

## Development
-------------

This section provides guidance for developers looking to contribute to the `git-pitch-gen` tool or set up a local development environment.

### Setting Up a Development Environment

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/guilhermehbueno/ollama-git-pitch-gen.git
    cd ollama-git-pitch-gen
    ```

2.  **Dependencies:**
    *   **Ollama:** Ensure Ollama is installed and running on your system. You can download it from [https://ollama.com/](https://ollama.com/). The `pitch install` script also handles Ollama installation.
    *   **Shell Environment:** A standard Unix-like shell (e.g., Bash) is required to run the scripts.
    *   **Git:** Git must be installed.

3.  **Understanding the Scripts:**
    *   `main.sh`: The main entry point for the `pitch` command. It parses arguments and calls relevant functions from the `lib/` directory.
    *   `lib/*.sh`: Contain the core logic for different commands and functionalities.
    *   `install.sh`: Handles the installation process, including setting up Ollama, creating models, and symlinking the `pitch` command.
    *   `prepare-commit-msg.sh`: The Git hook script.

### Running Scripts Locally

You can run the main script directly for testing purposes. From the root of the cloned repository:

```bash
# Example: Display usage (equivalent to 'pitch' or 'pitch help' if implemented)
./main.sh

# Example: Test the commit message generation for staged files
# (This would require manual setup of environment variables that pitch normally handles)
# For full end-to-end testing, it's often easier to use the installed 'pitch' command.
# However, you can source utility scripts and call functions directly in a test script:
# source lib/model.sh
# source lib/git.sh
# _get_git_diff "HEAD" # Example internal function call
```
For most development, it's recommended to use the `install.sh` script to set up a local version of `pitch`. You can modify the scripts in your cloned directory, and then run `sudo ./install.sh` again to update your local installation with your changes. Remember to uninstall any existing global `pitch` installation first if you want to avoid conflicts.

### Contribution Guidelines

1.  **Branching:**
    *   Create a new branch for each feature or bug fix: `git checkout -b feature/your-feature-name` or `git checkout -b fix/your-bug-fix`.

2.  **Coding Style:**
    *   Follow the existing shell scripting style (e.g., variable naming, function structure).
    *   Add comments to explain complex logic.
    *   Ensure scripts are executable (`chmod +x <script_name>`).

### Tests

- The lightweight regression suite at `tests/test_basic_commands.sh` exercises the `pitch help`, `pitch info`, `pitch apply`, `pitch model`, `pitch commit`, `pitch ask`, and `pitch pr` flows using a temporary Git repository.
- Each scenario prints a short "Expectation" description followed by the captured command output, making it easy to visually inspect the results.
- Each run also normalizes the transcript and compares it against golden files stored in `tests/golden`; refresh them after intentional behavior changes with:
    ```bash
    UPDATE_GOLDEN=1 ./tests/test_basic_commands.sh
    ```
- During testing the suite exports `DEV_MODE=1` and prepends `tests/mocks` to `PATH`, so calls to `gum`, `ollama`, `mods`, `gh`, `git ls-remote`, `pgrep`, `tput`, and `uname` are satisfied by deterministic stubs in `tests/mocks/`.
- Normalized copies of every run (and any diffs) are written to `tests/output/`; if a test drifts from its golden, check `<name>.diff` to review the delta and `<name>.actual` for the raw transcript.
- The harness was designed this way to keep coverage on CLI behavior without depending on real services or network access.
- Run everything locally from the repo root:
    ```bash
    ./tests/test_basic_commands.sh
    ```
- Green output signals that the core commands still behave as expected; any failures are summarized at the end of the run.

3.  **Testing:**
    *   Manually test your changes thoroughly.
    *   Consider how your changes might affect different commands or configurations.
    *   If adding a new command, ensure it's documented in this README under "Command Reference".

4.  **Commit Messages:**
    *   Write clear and concise commit messages. You can even use `pitch commit` (if installed from your development version) to generate them!

5.  **Pull Requests:**
    *   Submit a pull request to the `master` branch (or the main development branch).
    *   Provide a clear description of your changes in the pull request.
    *   Reference any relevant issues.

### Testing the Git Hook

1.  Modify `prepare-commit-msg.sh` in your local repository.
2.  To test it in a local Git repository (not your `git-pitch-gen` development repo, but another test repo):
    *   Copy your modified `prepare-commit-msg.sh` to `.git/hooks/prepare-commit-msg` in that test repository.
    *   Ensure it's executable: `chmod +x .git/hooks/prepare-commit-msg`.
    *   Stage some changes and run `git commit`.
    *   Observe the behavior and any output from your hook script.
    *   Remember to remove it or use `pitch apply` from a stable version when done testing.

## Troubleshooting
-----------------

**1. Ollama Server Issues:**
   - **Error: "Connection refused" or "Failed to connect to Ollama server."**
     - **Solution:** Ensure the Ollama server is running. You can start it with `pitch start` or the appropriate command for your Ollama installation.
     - **Solution:** Verify the Ollama server address and port if you have a custom setup.
   - **Error: "Ollama command not found."**
     - **Solution:** Make sure Ollama is correctly installed and its path is included in your system's PATH environment variable. The `pitch install` command attempts to handle this.

**2. Model Issues:**
   - **Error: "Model not found: <model-name>"**
     - **Solution:** Ensure the model specified in `~/.ollama-git-pitch-gen/prepare-commit-msg.properties` (or the default) is available locally. You can create/pull models using `pitch create_model <model-name>` or standard Ollama commands (e.g., `ollama pull <model-name>`).
     - **Solution:** Check for typos in the model name in your configuration. Use `pitch model` to see available `pitch_*` models and select one.
   - **Error: "Failed to pull model."**
     - **Solution:** Check your internet connection. Ensure you can reach the Ollama model repository.

**3. Git Hook Issues:**
   - **Commit messages are not being auto-generated.**
     - **Solution:** Verify that the Git hook is installed correctly in your current repository by running `pitch apply`.
     - **Solution:** Check the permissions of the `.git/hooks/prepare-commit-msg` file. It should be executable.
     - **Solution:** Look for error messages in your terminal when you try to commit.
   - **AI-generated message is a comment, but I want it to be the default.**
     - **Solution:** Set `ALLOW_COMMIT_OVERRIDE=true` in `~/.ollama-git-pitch-gen/prepare-commit-msg.properties`.

**4. Script Execution Issues:**
   - **Error: "Permission denied" when running `pitch` commands.**
     - **Solution:** Ensure the `pitch` script (usually in `~/.local/bin` or `/usr/local/bin`) has execute permissions. The installation script should handle this, but you might need to use `chmod +x <path_to_pitch_script>`.
     - **Solution:** Check permissions for the installation directory `~/.ollama-git-pitch-gen` and its contents.

## License
---------
This project is licensed under the MIT License.
