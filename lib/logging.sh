# ───────────────────────────────────────────────────────────
# 🔹 LOGGING FUNCTIONS
# ───────────────────────────────────────────────────────────
log_message() {
    local level="$1"
    local message="$2"
    if [[ "$DISABLE_LOGS" != "true" ]]; then
        gum log --level "$level" "$message"
    fi
    [[ "$level" == "error" ]] && exit 1
}

log() {
    if [[ "$DISABLE_LOGS" != "true" ]]; then
        gum log --level info "$1"
    fi
}
warn() {
    if [[ "$DISABLE_LOGS" != "true" ]]; then
        gum log --level warn "$1"
    fi
}
error() {
    if [[ "$DISABLE_LOGS" != "true" ]]; then
        gum log --level error "$1"
    fi
    exit 1
}