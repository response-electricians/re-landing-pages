#!/usr/bin/env bash
#
# check-claims.sh — pre-deploy guard against claims we must never publish.
#
# Raised by Brendan Bailey (GM) after "no call-out fee" wording went live and
# after private revenue figures were briefly published on a blog post.
# This is a cheap grep gate: it fails the build if any banned phrase appears in
# the HTML we deploy, so it gets caught BEFORE it goes live, not months later.
#
# Run locally:   ./scripts/check-claims.sh
# CI runs it automatically on every pull request (.github/workflows/claims-check.yml).
#
# Exit 0 = clean. Exit 1 = at least one banned phrase found (see output).

set -uo pipefail

# Resolve repo root regardless of where the script is called from.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Only scan what we actually deploy. Skip the git dir, archived deploy snapshots,
# node_modules, and this script itself.
FILES=$(find . \
  -type d \( -name .git -o -name node_modules -o -name deploys -o -name scripts \) -prune -o \
  -type f -name '*.html' -print)

# Banned phrases. Each entry: "regex (case-insensitive)|plain-English why".
# NOTE: we match the PROMISE, not the words alone — e.g. "no call-out fee" is
# banned, but "call-out fees stack up" (a pain point about others) is fine.
BANNED=(
  "no[ -]call[ -]?out fee|We charge call-out fees and must reserve the right to."
  "no[ -]callout fee|We charge call-out fees and must reserve the right to."
  "no emergency surcharge|We must reserve the right to charge for urgent/after-hours attendance."
  "no[ -]surcharge|We must reserve the right to charge a surcharge."
  "no exceptions|Absolute warranty language removes our ability to decline a claim."
  "free quote|Use 'no-obligation quote' — 'free quote' has caused issues before."
)

# High-signal confidentiality markers — private financials must never ship.
CONFIDENTIAL=(
  "simpro sales data|Internal Simpro data must not be published."
  "install volume|Internal volume/revenue detail must not be published."
  "monthly revenue|Private revenue figures must not be published."
  "annual revenue|Private revenue figures must not be published."
)

fail=0

# scan LABEL rule [rule ...]  — kept bash-3.2 compatible (macOS ships 3.2, no namerefs).
scan() {
  label="$1"; shift
  for entry in "$@"; do
    pattern="${entry%%|*}"
    why="${entry#*|}"
    # grep across the deploy set; -I skips binaries, -n gives line numbers.
    hits=$(echo "$FILES" | tr '\n' '\0' | xargs -0 grep -IniE "$pattern" 2>/dev/null)
    if [ -n "$hits" ]; then
      fail=1
      echo ""
      echo "  ✗ [$label] banned: /$pattern/"
      echo "    why: $why"
      echo "$hits" | sed 's/^/      /'
    fi
  done
}

echo "Scanning deployable HTML for banned claims and confidential markers…"
scan "CLAIM" "${BANNED[@]}"
scan "CONFIDENTIAL" "${CONFIDENTIAL[@]}"

echo ""
if [ "$fail" -eq 0 ]; then
  echo "✓ Clean — no banned phrases found."
  exit 0
else
  echo "✗ Banned phrases found. Fix the lines above before deploying."
  echo "  (If a match is a legitimate use, refine the regex in scripts/check-claims.sh"
  echo "   rather than deleting the rule.)"
  exit 1
fi
