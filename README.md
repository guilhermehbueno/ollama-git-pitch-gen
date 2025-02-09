# Introduction

`git-pitch-gen` is a CLI tool designed to automate the process of generating meaningful Git commit messages using AI. By integrating with **Ollama**, `git-pitch-gen` analyzes the changes in your staged files and suggests structured, context-aware commit messages.  

This tool enhances the commit workflow by providing **AI-powered insights** into the changes being made, reducing the effort required to craft clear and concise commit messages.  

With built-in **Git hook support**, `git-pitch-gen` ensures that AI-generated commit messages are seamlessly integrated into your development workflow.

# Features

✔ **AI-Powered Commit Messages** – Uses an LLM to analyze Git diffs and generate meaningful commit messages.  
✔ **Git Hook Integration** – Automatically runs before committing to suggest structured messages.  
✔ **Customizable Configuration** – Modify AI models, prompt behavior, and commit formatting via a properties file.  
✔ **Model Selection Support** – Easily switch between different AI models with the `pitch model` command.  
✔ **Supports Custom Models** – Use predefined models (`Modelfile`, `DeepSeekModelfile`) or define your own.  
✔ **Seamless Installation & Management** – Simple setup with `install.sh`, and easy start/stop controls for the Ollama server.  
✔ **Error Handling & Logging** – Provides clear feedback in case of failures and logs issues for troubleshooting.  
✔ **Non-Intrusive Workflow** – Maintains manual commit capabilities while offering AI-generated suggestions.  

# Installation

## Prerequisites
Before installing `git-pitch-gen`, ensure you have the following dependencies:

- **Git** – Required for integrating the commit message hook.
- **Ollama** – Used for running AI models locally. Install it from [Ollama’s official website](https://ollama.ai).
- **A supported AI model** – You can use the built-in models or add your own.

## Quick Install
Run the following command to download and install `git-pitch-gen`:

```bash
curl -sSL https://your-url/install.sh | bash
git clone https://github.com/your-repo/git-pitch-gen.git
cd git-pitch-gen
./install.sh install
```

## Verifying Installation

Once installed, you can verify that git-pitch-gen is set up correctly by running:

```bash
pitch info
```


# Usage
## Running the `pitch` Command
## Switching Models (`pitch model`)
## Generating Commit Messages

# Configuration
## `prepare-commit-msg.properties` Settings
## Explanation of Available Options

# Customizing Models
## Understanding `Modelfile` and `DeepSeekModelfile`
## Creating and Using Custom Models

# How the Git Hook Works
## Integration of `prepare-commit-msg.sh` into Git
## Manually Installing the Git Hook

# Main Script (`main.sh`)
## Overview of Core Functionality
## Interaction with Ollama

# Troubleshooting
## Common Issues and Fixes
## Checking Logs

# Contributing

# License