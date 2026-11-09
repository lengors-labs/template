#!/usr/bin/env bash
set -euo pipefail

# The token action may have failed before producing a token. Avoid empty-string
# matches, which would otherwise match every line and URL.
if [[ -z "${TOKEN:-}" ]]; then
  exit 0
fi

if ! config_path=$(git rev-parse --path-format=absolute --git-path config 2>/dev/null); then
  echo '::error::Could not locate the Git configuration for cleanup'
  exit 1
fi
if ! fetch_head=$(git rev-parse --path-format=absolute --git-path FETCH_HEAD 2>/dev/null); then
  echo '::error::Could not locate FETCH_HEAD for cleanup'
  exit 1
fi

# Restore only the expected credential-bearing origin URL. Keep URL changes
# going through Git instead of rewriting config by hand.
if git remote get-url origin >/dev/null 2>&1; then
  if ! url=$(git config --local --get remote.origin.url 2>/dev/null); then
    echo '::error::Could not read the origin URL during credential cleanup'
    exit 1
  fi
  credential="x-access-token:${TOKEN}@"
  if [[ "$url" == *"$credential"* ]]; then
    clean_url=${url//"$credential"/}
    if ! git remote set-url origin "$clean_url" 2>/dev/null; then
      echo '::error::Could not restore a credential-free origin URL'
      exit 1
    fi
  fi
fi

# FETCH_HEAD is transient Git metadata. Filter only lines containing this token,
# using a same-directory temporary file for an atomic move.
if [[ -e "$fetch_head" ]]; then
  if ! tmp=$(mktemp "${fetch_head}.XXXXXX"); then
    echo '::error::Could not create a temporary FETCH_HEAD cleanup file'
    exit 1
  fi
  cleanup_tmp() { rm -f -- "$tmp"; }
  trap cleanup_tmp EXIT

  if grep -F -v -- "$TOKEN" "$fetch_head" > "$tmp"; then
    :
  else
    grep_status=$?
    if (( grep_status != 1 )); then
      echo '::error::Could not read FETCH_HEAD during credential cleanup'
      exit 1
    fi
  fi

  if ! chmod --reference="$fetch_head" "$tmp" 2>/dev/null; then
    echo '::error::Could not preserve FETCH_HEAD permissions during cleanup'
    exit 1
  fi
  if ! mv -f -- "$tmp" "$fetch_head"; then
    echo '::error::Could not replace FETCH_HEAD during credential cleanup'
    exit 1
  fi
  trap - EXIT
fi

# Inspect both targets, treating missing FETCH_HEAD as normal but any unreadable
# metadata as a cleanup failure. Never print the token.
for path in "$config_path" "$fetch_head"; do
  [[ -e "$path" ]] || continue
  if grep -F -q -- "$TOKEN" "$path" 2>/dev/null; then
    echo '::error::The App token is still present in the checkout'
    exit 1
  else
    grep_status=$?
    if (( grep_status != 1 )); then
      echo '::error::Could not verify Git metadata after credential cleanup'
      exit 1
    fi
  fi
done
