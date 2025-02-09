# git-pitch-gen

## Introduction

`git-pitch-gen` is a CLI tool designed to automate the process of generating meaningful Git commit messages using AI. By integrating with **Ollama**, `git-pitch-gen` analyzes the changes in your staged files and suggests structured, context-aware commit messages.

This tool enhances the commit workflow by providing **AI-powered insights** into the changes being made, reducing the effort required to craft clear and concise commit messages.

With built-in **Git hook support**, `git-pitch-gen` ensures that AI-generated commit messages are seamlessly integrated into your development workflow.

---

## Features

- ✅ **AI-Powered Commit Messages** – Uses an LLM to analyze Git diffs and generate meaningful commit messages.
- ✅ **Git Hook Integration** – Automatically runs before committing to suggest structured messages.
- ✅ **Customizable Configuration** – Modify AI models, prompt behavior, and commit formatting via a properties file.
- ✅ **Model Selection Support** – Easily switch between different AI models with the `pitch model` command.
- ✅ **Supports Custom Models** – Use predefined models (`Modelfile`, `DeepSeekModelfile`) or define your own.
- ✅ **Seamless Installation & Management** – Simple setup with `install.sh`, and easy start/stop controls for the Ollama server.
- ✅ **Error Handling & Logging** – Provides clear feedback in case of failures and logs issues for troubleshooting.
- ✅ **Non-Intrusive Workflow** – Maintains manual commit capabilities while offering AI-generated suggestions.

---

## Installation

### Prerequisites

Before installing `git-pitch-gen`, ensure you have the following dependencies:

- **Git** – Required for integrating the commit message hook.
- **Ollama** – Used for running AI models locally. Install it from [Ollama’s official website](https://ollama.ai).
- **A supported AI model** – You can use the built-in models or add your own.

### Quick Install

Run the following command to download and install `git-pitch-gen`:

```bash
curl -sSL https://your-url/install.sh | bash
git clone https://github.com/your-repo/git-pitch-gen.git
cd git-pitch-gen
./install.sh install
```

### Verifying Installation

Once installed, you can verify that `git-pitch-gen` is set up correctly by running:

```bash
pitch info
```

---

## Usage

### Running the `pitch` Command

To manually generate a commit message based on staged changes, run:

```bash
pitch model
```

### Switching Models (`pitch model`)

If you have multiple models installed, you can switch between them using:

```bash
pitch model
```

This command lists available models and allows you to select one interactively.

### Generating Commit Messages

Once installed, commit messages are automatically generated when you run:

```bash
git commit
```

The AI-generated message will be suggested based on the detected changes.

---

## Configuration

### `prepare-commit-msg.properties` Settings

Configuration settings can be customized in the `prepare-commit-msg.properties` file:

```properties
OLLAMA_MODEL=git-assistant
OLLAMA_PROMPT=Generate a meaningful Git commit message for the following change:
MAX_DIFF_LINES=150
ALLOW_COMMIT_OVERRIDE=false
```

### Explanation of Available Options

- `OLLAMA_MODEL`: Defines the AI model used for generating commit messages.
- `OLLAMA_PROMPT`: The prompt given to the AI when generating a commit message.
- `MAX_DIFF_LINES`: The maximum number of diff lines considered for commit message generation.
- `ALLOW_COMMIT_OVERRIDE`: If `false`, AI-generated messages are appended as a comment instead of replacing the commit message.

---

## Customizing Models

### Understanding `Modelfile` and `DeepSeekModelfile`

By default, `git-pitch-gen` supports two models defined in:

- `Modelfile` – The standard model definition.
- `DeepSeekModelfile` – A secondary model that can be used as an alternative.

### Creating and Using Custom Models

To create a custom model, define a `Modelfile` with the necessary configurations and run:

```bash
ollama create <model-name> -f Modelfile
```

You can then select the new model using:

```bash
pitch model
```

---

## How the Git Hook Works

### Integration of `prepare-commit-msg.sh` into Git

The `prepare-commit-msg.sh` script is automatically installed as a Git hook, ensuring AI-generated commit messages are suggested during the commit process.

### Manually Installing the Git Hook

If you need to manually install the hook, run:

```bash
pitch apply
```

This will copy the required scripts into your `.git/hooks/` directory.

---

## Main Script (`main.sh`)

### Overview of Core Functionality

The `main.sh` script provides essential installation, model management, and server control functions, including:

- Installing and managing Ollama.
- Downloading and creating AI models.
- Installing Git hooks.
- Starting and stopping the Ollama server.

### Interaction with Ollama

The tool interacts with Ollama through:

- `ollama serve` – Starts the Ollama server.
- `ollama list` – Lists installed models.
- `ollama pull <model-url>` – Downloads a model.
- `ollama create <model-name> -f Modelfile` – Creates a model.

---

## Troubleshooting

### Common Issues and Fixes

#### Ollama is not installed

Run:

```bash
pitch install
```

#### Ollama is not running

Start the server manually:

```bash
ollama serve &
```

#### AI-generated messages are not appearing

Ensure the Git hook is installed:

```bash
pitch apply
```

### Checking Logs

Logs are stored in `~/.ollama_server.log`. View them using:

```bash
tail -f ~/.ollama_server.log
```

---

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests to improve `git-pitch-gen`.

---

## License

`git-pitch-gen` is licensed under the MIT License. See [LICENSE](LICENSE) for details.





