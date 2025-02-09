# Git Pitch Generator (`git-pitch-gen`)

🚀 **Automate Your Git Commit Messages & Pull Requests with AI**

`git-pitch-gen` is a CLI tool that integrates with **Ollama** to generate meaningful commit messages and pull request descriptions using AI.

---

## **📌 Features**

✔ **AI-Powered Commit Messages** – Uses an LLM to analyze Git diffs and generate structured commit messages.\
✔ **Git Hook Integration** – Automatically runs before committing.\
✔ **Customizable AI Models** – Easily switch models with `pitch model`.\
✔ **AI-Generated Pull Requests** – Automate PR descriptions with `pitch pr`.\
✔ **Flexible Configuration** – Modify behavior using `.properties` files.\
✔ **Seamless GitHub PR Creation** – Uses `gh` CLI to create PRs automatically.

---

## **📌 Installation**

### **Prerequisites**

Ensure you have:

- **Git** – Required for integrating commit hooks.
- **Ollama** – Used for AI-based message generation. Install via [Ollama’s website](https://ollama.ai).
- **GitHub CLI (********`gh`********)** – Required if you want automatic PR creation.

### **Install via Script**

```bash
curl -sSL https://your-url/install.sh | bash
```

### **Manual Installation**

```bash
git clone https://github.com/your-repo/git-pitch-gen.git
cd git-pitch-gen
./main.sh install
```

---

## **📌 Usage**

### **Generating AI-Powered Commit Messages**

Once installed, AI-generated commit messages will be suggested automatically:

```bash
git add .
git commit
```

### **Manually Generate a Commit Message**

```bash
pitch generate
```

### **Switching AI Models**

To select a different model for commit generation:

```bash
pitch model
```

- Lists all available AI models.
- Prompts the user to select one.
- Saves the selection in `.git/hooks/prepare-commit-msg.properties`.

### **AI-Generated Pull Requests**

To generate a **Pull Request title and description** using AI:

```bash
pitch pr main
```

This will:

- Compare the current branch to `main`
- Generate a **PR title and summary** using AI
- Display the PR description in **Markdown**
- If `gh` is installed, automatically create the PR

To **disable automatic PR creation**, use:

```bash
pitch pr main --text-only
```

---

## **📌 Customizing AI Models**

**Note:** If you create a model manually using `ollama create`, ensure that the model name starts with `pitch_` to be recognized by `git-pitch-gen`.

By default, `git-pitch-gen` uses `Modelfile.sample` to define AI model behavior.

To **create a new AI model**, modify `Modelfile.sample` and create a model:

```bash
ollama create my-custom-model -f Modelfile.sample
```

Alternatively, you can use the built-in command:

```bash
pitch create_model <model-name>
```

Then, **set it as the active model**:

```bash
pitch model
```

**Note:** If you create a model manually using `ollama create`, ensure that the model name starts with `pitch_` to be recognized by `git-pitch-gen`.

By default, `git-pitch-gen` uses `Modelfile.sample` to define AI model behavior.

## **📌 Git Hook Setup**

To manually install the commit message hook:

To manually install the commit message hook:

```bash
pitch apply
```

This will:

- Copy `prepare-commit-msg.sh` into `.git/hooks/`
- Copy `prepare-commit-msg.properties` for model configuration
- Ensure AI-generated commit messages are used before committing.

---

## **📌 Configuration**

### **Modify AI Behavior**

Configuration is stored in `.git/hooks/prepare-commit-msg.properties`:

```ini
OLLAMA_MODEL=pitch_deepseek-coder
UNIFIED_LINES=5
ALLOW_COMMIT_OVERRIDE=false
```

To change settings:

```bash
nano .git/hooks/prepare-commit-msg.properties
```

---

## **📌 Troubleshooting**

### **Check Installed Models**

```bash
ollama list
```

### **Verify Hook Installation**

```bash
ls .git/hooks/prepare-commit-msg
```

### **View AI Logs**

```bash
tail -f ~/.ollama_server.log
```

---

## **📌 Contributing**

Contributions are welcome! Please submit issues and PRs to improve `git-pitch-gen`.

---

## **📌 License**

MIT License © 2024 Braveinnov

