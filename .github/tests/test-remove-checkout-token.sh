#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/.github/scripts/remove-checkout-token.sh"
WORKFLOW="$ROOT/.github/workflows/publish-new-version.yml"
TOKEN='test-token-123'
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

tests_run=0
fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}
assert_eq() {
  [[ "$1" == "$2" ]] || fail "$3 (expected '$2', got '$1')"
}
assert_contains() {
  [[ "$1" == *"$2"* ]] || fail "$3"
}
assert_not_contains() {
  [[ "$1" != *"$2"* ]] || fail "$3"
}
new_repo() {
  REPO="$TMP/$1"
  mkdir -p "$REPO"
  git -C "$REPO" init --quiet
}
run_cleanup() {
  local token=${1-$TOKEN}
  shift || true
  local output status=0
  output=$(cd "$REPO" && TOKEN="$token" PATH="${TEST_PATH:-$PATH}" bash "$SCRIPT" 2>&1) || status=$?
  assert_not_contains "$output" "$TOKEN" 'cleanup leaked the token in output'
  [[ -z "$output" ]] || printf '%s\n' "$output"
  return "$status"
}
pass() {
  printf 'ok %s - %s\n' "$((tests_run + 1))" "$1"
  tests_run=$((tests_run + 1))
}
install_wrapper() {
  local name=$1 body=$2
  mkdir -p "$TMP/wrappers"
  cat > "$TMP/wrappers/$name" <<EOF
#!/usr/bin/env bash
$body
EOF
  chmod +x "$TMP/wrappers/$name"
  TEST_PATH="$TMP/wrappers:$PATH"
  export TEST_PATH REAL_GIT REAL_GREP
}

REAL_GIT=$(command -v git)
REAL_GREP=$(command -v grep)
export REAL_GIT REAL_GREP

# Normal checkout: restore only the URL credential, drop token-bearing fetch
# lines, and preserve unrelated config and FETCH_HEAD lines.
new_repo 'normal checkout'
REPO_CONFIG=$(git -C "$REPO" rev-parse --path-format=absolute --git-path config)
FETCH_HEAD=$(git -C "$REPO" rev-parse --path-format=absolute --git-path FETCH_HEAD)
git -C "$REPO" remote add origin "https://x-access-token:${TOKEN}@github.com/example/repo.git"
git -C "$REPO" config --local user.name 'Preserved User'
printf 'keep-this-line\nremove-token-%s\n' "$TOKEN" > "$FETCH_HEAD"
run_cleanup
assert_eq "$(git -C "$REPO" remote get-url origin)" 'https://github.com/example/repo.git' 'origin URL not restored'
assert_eq "$(git -C "$REPO" config --local user.name)" 'Preserved User' 'unrelated config changed'
assert_eq "$(cat "$FETCH_HEAD")" 'keep-this-line' 'unrelated FETCH_HEAD content changed'
assert_not_contains "$(cat "$REPO_CONFIG")" "$TOKEN" 'token remains in config'
pass 'restores credentials and preserves unrelated metadata'

# No token must be a no-op, not an empty-pattern match.
original_config=$(cat "$REPO_CONFIG")
run_cleanup ''
assert_eq "$(cat "$REPO_CONFIG")" "$original_config" 'empty token modified config'
pass 'empty token is a no-op'

# Missing FETCH_HEAD is normal.
new_repo 'no fetch head'
run_cleanup
pass 'missing FETCH_HEAD is allowed'

# Missing checkout is handled by workflow gating, while direct script invocation
# reports the absence of Git metadata without leaking credentials.
REPO="$TMP/not a repo"
mkdir -p "$REPO"
status=0
output=$(cd "$REPO" && TOKEN="$TOKEN" bash "$SCRIPT" 2>&1) || status=$?
assert_eq "$status" '1' 'script should fail when invoked without a checkout'
assert_not_contains "$output" "$TOKEN" 'missing-checkout path leaked the token'
pass 'fails safely when invoked outside a checkout'

# Linked worktree: metadata paths are not rooted beneath a .git directory.
new_repo 'worktree main'
git -C "$REPO" -c user.name=Test -c user.email=test@example.com commit --allow-empty --quiet -m Initial
git -C "$REPO" remote add origin "https://x-access-token:${TOKEN}@github.com/example/repo.git"
git -C "$REPO" worktree add --detach "$TMP/linked worktree" --quiet
REPO="$TMP/linked worktree"
FETCH_HEAD=$(git -C "$REPO" rev-parse --path-format=absolute --git-path FETCH_HEAD)
printf 'fetch-token-%s\n' "$TOKEN" > "$FETCH_HEAD"
run_cleanup
assert_not_contains "$(git -C "$REPO" config --local --get remote.origin.url)" "$TOKEN" 'worktree config contains token'
assert_not_contains "$(cat "$FETCH_HEAD")" "$TOKEN" 'worktree FETCH_HEAD contains token'
pass 'handles linked worktrees and paths containing spaces'

# Simulate git refusing to restore the remote.
new_repo 'remote write failure'
git -C "$REPO" remote add origin "https://x-access-token:${TOKEN}@github.com/example/repo.git"
install_wrapper git 'if [[ "$1 $2" == "remote set-url" ]]; then exit 2; fi; exec "$REAL_GIT" "$@"'
status=0
output=$(run_cleanup 2>&1) || status=$?
assert_eq "$status" '1' 'failed remote update should fail cleanup'
assert_contains "$output" 'Could not restore a credential-free origin URL' 'missing remote failure diagnostic'
pass 'fails if origin cannot be restored'
unset TEST_PATH

# Simulate grep reporting an actual read error rather than "no matches".
new_repo 'FETCH_HEAD read failure'
FETCH_HEAD=$(git -C "$REPO" rev-parse --path-format=absolute --git-path FETCH_HEAD)
printf 'token-%s\n' "$TOKEN" > "$FETCH_HEAD"
install_wrapper grep 'if [[ "$*" == *"-v"* ]]; then exit 2; fi; exec "$REAL_GREP" "$@"'
status=0
output=$(run_cleanup 2>&1) || status=$?
assert_eq "$status" '1' 'grep read error should fail cleanup'
assert_contains "$output" 'Could not read FETCH_HEAD' 'missing FETCH_HEAD failure diagnostic'
pass 'fails on FETCH_HEAD read errors'
unset TEST_PATH

# Leave the credentialed remote untouched to exercise the residual-token guard.
new_repo 'residual token'
git -C "$REPO" remote add origin "https://x-access-token:${TOKEN}@github.com/example/repo.git"
install_wrapper git 'if [[ "$1 $2" == "remote set-url" ]]; then exit 0; fi; exec "$REAL_GIT" "$@"'
status=0
output=$(run_cleanup 2>&1) || status=$?
assert_eq "$status" '1' 'remaining token should fail cleanup'
assert_contains "$output" 'The App token is still present' 'missing residual-token diagnostic'
pass 'fails when verification finds a residual token'
unset TEST_PATH

# Ensure the workflow always runs cleanup after a successful checkout and calls
# the checked-in script rather than embedding its implementation.
cleanup_step=$(sed -n '/- name: Remove the token from the checkout/,$p' "$WORKFLOW")
assert_contains "$cleanup_step" 'if: always() && steps.checkout.outcome == '\''success'\''' 'cleanup step is not unconditional after checkout'
assert_contains "$cleanup_step" 'run: bash .github/scripts/remove-checkout-token.sh' 'workflow does not invoke cleanup script'
pass 'workflow invokes the script in an always-run post-checkout step'

printf '1..%s\n' "$tests_run"
