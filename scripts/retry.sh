#!/bin/sh

# Retry a command that touches the network.
#
# Why this exists: a single `apply` job makes roughly 300 network requests --
# 208 crate downloads for git-delta, 74 apt fetches, plus rustup, lazygit,
# chezmoi and its 14 externals. None of them used to retry, so at a realistic
# per-request failure rate the *job* failed far more often than any one request
# did, and the weekly dependency-bump PR nearly always needed a manual re-run.
# Every flaky failure on record was an HTTP 503/504 from GitHub or a dropped
# connection -- never a checksum mismatch or a real defect.
#
# Most callers do not need this: `curl --retry` and apt's Acquire::Retries
# handle their own requests. This is for operations that do their networking
# *internally*, where our flags cannot reach:
#
#   - `sh -c "$(curl ... get.chezmoi.io)"` -- our curl flags protect fetching
#     the installer script, not the chezmoi binary it downloads afterwards.
#   - `chezmoi apply` -- externals are fetched by chezmoi's own Go HTTP client,
#     which has no retry option (--refresh-externals is the only related flag).
#
# Retrying is safe for both because they are idempotent: chezmoi apply is
# re-run unconditionally by CI's own idempotence check, and a re-run skips work
# that already completed.
#
# Usage: scripts/retry.sh <attempts> <command> [args...]

set -eu

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <attempts> <command> [args...]" >&2
  exit 2
fi

attempts="$1"
shift

attempt=1
delay=2

while :; do
  status=0
  "$@" || status=$?

  if [ "$status" -eq 0 ]; then
    exit 0
  fi

  if [ "$attempt" -ge "$attempts" ]; then
    echo "retry: '$1' failed on attempt ${attempt}/${attempts} (exit ${status}); giving up" >&2
    exit "$status"
  fi

  echo "retry: '$1' failed on attempt ${attempt}/${attempts} (exit ${status}); retrying in ${delay}s" >&2
  sleep "$delay"

  attempt=$((attempt + 1))
  # Exponential backoff, capped so a long outage does not stall the job for
  # minutes between attempts.
  delay=$((delay * 2))
  if [ "$delay" -gt 30 ]; then
    delay=30
  fi
done
