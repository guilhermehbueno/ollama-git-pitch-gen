
# ───────────────────────────────────────────────────────────
# 🔹 HELPER FUNCTIONS
# ───────────────────────────────────────────────────────────


replace_template_values() {
    local template="$1"
    shift

    while [[ "$#" -gt 0 ]]; do
        local key="$1"
        local value="$2"
        shift 2

        key="<$key>"
        template="${template//$key/$value}"
    done

    echo "$template"
}


# ───────────────────────────────────────────────────────────
# 🔹 PARSE ARGUMENTS FUNCTIONS
# ───────────────────────────────────────────────────────────
parse_arguments() {
    local prev_key=""

    for arg in "$@"; do
        if [[ "$arg" == --* ]]; then
            prev_key=""
            value=""
            if [[ "$arg" == *=* ]]; then
                prev_key="${arg%%=*}"  # Extract key before '='
                prev_key="${prev_key#--}"  # Remove '--' prefix
                prev_key="${prev_key//-/_}"  # Convert dashes to underscores for valid variable names
                prev_key=$(echo "$prev_key" | tr '[:lower:]' '[:upper:]')  # Convert to uppercase
                value="${arg#*=}"  # Extract value after '='
                log "Declaring: $prev_key=${value}"
                eval "$prev_key"="$value"
            else
                prev_key="${arg#--}"  # Remove '--' prefix
                prev_key="${prev_key//-/_}"  # Convert dashes to underscores
                prev_key=$(echo "$prev_key" | tr '[:lower:]' '[:upper:]')  # Convert to uppercase
                log "Declaring: $prev_key=true"
                eval "$prev_key"=true
            fi
        fi
    done
}