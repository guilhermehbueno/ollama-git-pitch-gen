#!/usr/bin/env bash
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
GOLDEN_DIR="$TEST_DIR/golden"
OUTPUT_DIR="$TEST_DIR/output"
TMP_ROOT="$TEST_DIR/tmp"

mkdir -p "$GOLDEN_DIR" "$OUTPUT_DIR" "$TMP_ROOT"
export TMPDIR="$TMP_ROOT"

export DEV_MODE=1
export DISABLE_LOGS=true

if [[ -z "${REAL_GIT:-}" ]]; then
  export REAL_GIT
  REAL_GIT="$(command -v git)"
fi

export PATH="$TEST_DIR/mocks:$PATH"

tests_run=0
failures=0
fail_messages=()

print_log() {
  local log="$1"
  printf '%s' "$log"
  [[ "$log" == *$'\n' ]] || printf '\n'
}

normalize_output() {
  local name="$1"
  python3 -c '
import sys
import re

name, repo_root, test_dir, tmp_root, home = sys.argv[1:6]
text = sys.stdin.read()

replacements = [
    (repo_root, "<REPO_ROOT>"),
    (test_dir, "<TEST_DIR>"),
    (tmp_root, "<TMPDIR>"),
    (home, "<HOME>"),
]

for target, replacement in replacements:
    text = text.replace(target, replacement)

text = re.sub(r"tmp_repo\.[A-Za-z0-9_-]+", "tmp_repo.XXXXXX", text)
text = re.sub(r"tmp\.[A-Za-z0-9_-]+", "tmp.XXXXXX", text)
text = re.sub(r"\[main \(root-commit\) [0-9a-f]{7}\]", "[main (root-commit) <HASH>]", text)
text = re.sub(r"[0-9a-f]{40}", "<GIT_HASH>", text)
text = re.sub(r"\*\*🖥️   OS:\*\*.*", "**🖥️   OS:** <UNAME>", text)
text = re.sub(r"\*\*💻  Shell:\*\*.*", "**💻  Shell:** <SHELL>", text)
text = re.sub(r"🔍 Latest installed commit: .*", "🔍 Latest installed commit: <GIT_HASH>", text)
text = re.sub(r"✅ \*\*Your installation is up to date\.\*\*", "✅ **Your installation is up to date.**", text)
text = re.sub(r"🔗 \*\*Symlink for pitch is set up at:\*\* .*", "🔗 **Symlink for pitch is set up at:** <SYMLINK_TARGET>", text)

print(text, end="")
' "$name" "$REPO_ROOT" "$TEST_DIR" "$TMP_ROOT" "${HOME:-}"
}

compare_with_golden() {
  local name="$1"
  local log="$2"

  print_log "$log"

  local actual_file="$OUTPUT_DIR/${name}.actual"
  local normalized_file="$OUTPUT_DIR/${name}.normalized"
  local diff_file="$OUTPUT_DIR/${name}.diff"
  local golden_file="$GOLDEN_DIR/${name}.txt"

  local log_with_newline="$log"
  if [[ "$log_with_newline" != *$'\n' ]]; then
    log_with_newline+=$'\n'
  fi

  printf '%s' "$log_with_newline" > "$actual_file"

  local normalized
  normalized="$(printf '%s' "$log_with_newline" | normalize_output "$name")"
  printf '%s' "$normalized" > "$normalized_file"
  if [[ "$normalized" != *$'\n' ]]; then
    echo >> "$normalized_file"
    normalized+=$'\n'
  fi

  if [[ "${UPDATE_GOLDEN:-}" == "1" ]]; then
    printf '%s' "$normalized" > "$golden_file"
  fi

  if [[ ! -f "$golden_file" ]]; then
    record_failure "$name" "missing golden file $golden_file"
    return 1
  fi

  if ! diff -u "$golden_file" "$normalized_file" > "$diff_file"; then
    record_failure "$name" "output drifted from golden (see $diff_file)"
    return 1
  fi

  rm -f "$diff_file"
  return 0
}

record_failure() {
  local name="$1"
  local message="$2"
  failures=$((failures + 1))
  fail_messages+=("$name: $message")
  echo "FAIL"
}

run_test() {
  local name="$1"
  shift
  tests_run=$((tests_run + 1))
  printf '• %s... ' "$name"
  if "$@"; then
    echo "OK"
  fi
}

assert_contains() {
  local text="$1"
  local needle="$2"
  [[ "$text" == *"$needle"* ]]
}

test_help_command() {
  local log=""
  log+=$'[help] Expectation: command prints usage instructions containing \'Usage: pitch\'.\n'

  local output
  if ! output="$("$REPO_ROOT/main.sh" help 2>&1)"; then
    log+=$'[help] Result:\n'
    log+="$output"$'\n'
    print_log "$log"
    record_failure "help" "command exited with failure"
    return 1
  fi

  log+=$'[help] Result:\n'
  log+="$output"$'\n'

  if ! assert_contains "$output" "Usage: pitch"; then
    log+=$'[help] Assertion failed: expected usage text.\n'
    print_log "$log"
    record_failure "help" "missing usage text"
    return 1
  fi

  compare_with_golden "help" "$log"
}

test_info_command() {
  local log=""
  log+=$'[info] Expectation: command surfaces Ollama version and model list.\n'

  local output
  if ! output="$("$REPO_ROOT/main.sh" info 2>&1)"; then
    log+=$'[info] Result:\n'
    log+="$output"$'\n'
    print_log "$log"
    record_failure "info" "command exited with failure"
    return 1
  fi

  log+=$'[info] Result:\n'
  log+="$output"$'\n'

  if ! assert_contains "$output" "ollama version mock"; then
    log+=$'[info] Assertion failed: ollama version not surfaced.\n'
    print_log "$log"
    record_failure "info" "ollama version not surfaced"
    return 1
  fi

  if ! assert_contains "$output" "pitch_llama3.1:latest"; then
    log+=$'[info] Assertion failed: model list missing expected entry.\n'
    print_log "$log"
    record_failure "info" "model list missing expected entry"
    return 1
  fi

  compare_with_golden "info" "$log"
}

test_apply_command() {
  local tmp_repo
  tmp_repo="$(mktemp -d "$TMPDIR/tmp_repo.XXXXXX")"

  local log=""
  log+=$'[apply] Expectation: hook files copied into temp repo and executable.\n'

  pushd "$tmp_repo" >/dev/null || return 1
  git init --quiet

  local output
  if ! output="$("$REPO_ROOT/main.sh" apply 2>&1)"; then
    log+=$'[apply] Result:\n'
    log+="$output"$'\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "apply" "command exited with failure"
    return 1
  fi

  log+=$'[apply] Result:\n'
  log+="$output"$'\n'

  local hooks_dir="$tmp_repo/.git/hooks"
  local hook_file="$hooks_dir/prepare-commit-msg"
  local hook_props="$hook_file.properties"
  local hook_commit_prompt="$hooks_dir/commit.prompt"
  local hook_pr_title="$hooks_dir/pr-title.prompt"
  local hook_pr_body="$hooks_dir/pr-description.prompt"

  if [[ ! -x "$hook_file" ]]; then
    log+=$'[apply] Assertion failed: prepare-commit-msg missing or not executable.\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "apply" "prepare-commit-msg missing or not executable"
    return 1
  fi

  for artifact in "$hook_props" "$hook_commit_prompt" "$hook_pr_title" "$hook_pr_body"; do
    if [[ ! -f "$artifact" ]]; then
      log+=$"[apply] Assertion failed: missing hook artifact $(basename "$artifact").\n"
      popd >/dev/null || true
      rm -rf "$tmp_repo"
      print_log "$log"
      record_failure "apply" "missing hook artifact $(basename "$artifact")"
      return 1
    fi
  done

  log+=$'[apply] Verified hook files.\n'

  popd >/dev/null || true
  rm -rf "$tmp_repo"

  compare_with_golden "apply" "$log"
}

test_model_command() {
  local tmp_repo
  tmp_repo="$(mktemp -d "$TMPDIR/tmp_repo.XXXXXX")"

  local log=""
  log+=$'[model] Expectation: user selection stored in hook properties.\n'

  pushd "$tmp_repo" >/dev/null || return 1
  git init --quiet

  local output
  if ! output=$(GUM_CHOOSE_SELECTION="pitch_llama3.2:latest" "$REPO_ROOT/main.sh" model 2>&1); then
    log+=$'[model] Result:\n'
    log+="$output"$'\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "model" "command exited with failure"
    return 1
  fi

  log+=$'[model] Result:\n'
  log+="$output"$'\n'

  local config_file="$tmp_repo/.git/hooks/prepare-commit-msg.properties"
  if [[ ! -f "$config_file" ]]; then
    log+=$'[model] Assertion failed: configuration file not created.\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "model" "configuration file not created"
    return 1
  fi

  if ! grep -q "^OLLAMA_MODEL=pitch_llama3.2:latest" "$config_file"; then
    log+=$'[model] Assertion failed: missing OLLAMA_MODEL entry.\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "model" "configuration missing expected OLLAMA_MODEL entry"
    return 1
  fi

  log+=$'[model] Verified configuration file.\n'

  popd >/dev/null || true
  rm -rf "$tmp_repo"

  compare_with_golden "model" "$log"
}

test_commit_command() {
  local tmp_repo
  tmp_repo="$(mktemp -d "$TMPDIR/tmp_repo.XXXXXX")"

  local log=""
  log+=$'[commit] Expectation: AI flow produces editable message and completes commit.\n'

  pushd "$tmp_repo" >/dev/null || return 1
  git init --quiet
  git config user.name "Pitch Tester"
  git config user.email "pitch-tester@example.com"

  if ! "$REPO_ROOT/main.sh" apply >/dev/null 2>&1; then
    log+=$'[commit] Assertion failed: failed to install hooks via apply.\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "commit" "failed to install hooks via apply command"
    return 1
  fi

  echo "test content" > sample.txt
  git add sample.txt

  local confirm_file
  confirm_file="$(mktemp "$TMPDIR/confirm.XXXXXX")"
  printf "no\nyes\n" > "$confirm_file"

  local output
  if ! output=$(GUM_CONFIRM_RESP_FILE="$confirm_file" GUM_WRITE_VALUE="Test commit message" "$REPO_ROOT/main.sh" commit 2>&1); then
    log+=$'[commit] Result:\n'
    log+="$output"$'\n'
    rm -f "$confirm_file"
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "commit" "command exited with failure"
    return 1
  fi

  rm -f "$confirm_file"

  log+=$'[commit] Result:\n'
  log+="$output"$'\n'

  local last_message
  last_message=$(git log -1 --pretty=%B)
  if [[ "$last_message" != "Test commit message" ]]; then
    log+=$'[commit] Assertion failed: unexpected commit message.\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "commit" "unexpected commit message: $last_message"
    return 1
  fi

  if [[ -n "$(git status --short)" ]]; then
    log+=$'[commit] Assertion failed: repository not clean after commit.\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "commit" "repository not clean after commit"
    return 1
  fi

  log+=$'[commit] Verified commit applied cleanly.\n'

  popd >/dev/null || true
  rm -rf "$tmp_repo"

  compare_with_golden "commit" "$log"
}

test_ask_command() {
  local choose_file
  choose_file="$(mktemp "$TMPDIR/choose.XXXXXX")"
  printf "pitch_llama3.1:latest\npitch_llama3.2:latest\n" > "$choose_file"

  local log=""
  log+=$'[ask] Expectation: selects both models and prints responses for each.\n'

  local output
  if ! output=$(GUM_CHOOSE_FILE="$choose_file" "$REPO_ROOT/main.sh" ask "What changed?" 2>&1); then
    log+=$'[ask] Result:\n'
    log+="$output"$'\n'
    rm -f "$choose_file"
    print_log "$log"
    record_failure "ask" "command exited with failure"
    return 1
  fi

  rm -f "$choose_file"

  log+=$'[ask] Result:\n'
  log+="$output"$'\n'

  if ! assert_contains "$output" "Mock response from pitch_llama3.1:latest."; then
    log+=$'[ask] Assertion failed: missing response for pitch_llama3.1:latest.\n'
    print_log "$log"
    record_failure "ask" "missing response for pitch_llama3.1:latest"
    return 1
  fi

  if ! assert_contains "$output" "Mock response from pitch_llama3.2:latest."; then
    log+=$'[ask] Assertion failed: missing response for pitch_llama3.2:latest.\n'
    print_log "$log"
    record_failure "ask" "missing response for pitch_llama3.2:latest"
    return 1
  fi

  compare_with_golden "ask" "$log"
}

test_pr_command() {
  local tmp_repo
  tmp_repo="$(mktemp -d "$TMPDIR/tmp_repo.XXXXXX")"

  local log=""
  log+=$'[pr] Expectation: generates PR title/body and skips gh creation in text-only mode.\n'

  pushd "$tmp_repo" >/dev/null || return 1
  git init --quiet

  echo "base line" > notes.txt
  git add notes.txt
  git commit -m "Initial commit" >/dev/null 2>&1
  git branch -M main >/dev/null 2>&1
  git checkout -b feature/test-pr >/dev/null 2>&1

  echo "feature line" >> notes.txt
  git add notes.txt
  git commit -m "Feature changes" >/dev/null 2>&1

  local output
  if ! output=$("$REPO_ROOT/main.sh" pr main --text-only 2>&1); then
    log+=$'[pr] Result:\n'
    log+="$output"$'\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "pr" "command exited with failure"
    return 1
  fi

  log+=$'[pr] Result:\n'
  log+="$output"$'\n'

  if ! assert_contains "$output" "Mock PR Title"; then
    log+=$'[pr] Assertion failed: missing generated PR title.\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "pr" "missing generated PR title"
    return 1
  fi

  if ! assert_contains "$output" "Mock PR description body."; then
    log+=$'[pr] Assertion failed: missing generated PR body.\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "pr" "missing generated PR body"
    return 1
  fi

  if ! assert_contains "$output" "Skipping GitHub PR creation"; then
    log+=$'[pr] Assertion failed: missing GitHub skip notice.\n'
    popd >/dev/null || true
    rm -rf "$tmp_repo"
    print_log "$log"
    record_failure "pr" "missing GitHub skip notice"
    return 1
  fi

  log+=$'[pr] Verified PR output.\n'

  popd >/dev/null || true
  rm -rf "$tmp_repo"

  compare_with_golden "pr" "$log"
}

main() {
  run_test "help command" test_help_command
  run_test "info command" test_info_command
  run_test "apply command" test_apply_command
  run_test "model command" test_model_command
  run_test "commit command" test_commit_command
  run_test "ask command" test_ask_command
  run_test "pr command" test_pr_command

  if (( failures > 0 )); then
    printf '\n%d/%d tests failed:\n' "$failures" "$tests_run"
    for msg in "${fail_messages[@]}"; do
      printf '  - %s\n' "$msg"
    done
    exit 1
  fi

  printf '\nAll %d tests passed.\n' "$tests_run"
}

main "$@"
