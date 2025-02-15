# ───────────────────────────────────────────────────────────
# 🔹 GIT FUNCTIONS
# ───────────────────────────────────────────────────────────

get_git_repo_root() {
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -z "$git_root" ]]; then
        error "❌ Not inside a Git repository."
    fi
    echo "$git_root"
}

