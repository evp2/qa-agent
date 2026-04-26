#!/usr/bin/env bash
# churn.sh — recency-weighted churn per file.
# Usage: bash churn.sh <repo-path>
# Emits TSV to stdout: path<TAB>weighted_score<TAB>commits_12mo<TAB>commits_24mo<TAB>commits_total
# Weights: last 12mo × 1.0, 12–24mo × 0.5, older × 0.1.

set -u

REPO="${1:-}"
if [[ -z "$REPO" ]]; then
  echo "usage: churn.sh <repo-path>" >&2
  exit 2
fi

if [[ ! -d "$REPO/.git" ]]; then
  echo "not a git repo: $REPO" >&2
  exit 1
fi

cd "$REPO" || exit 1

# Date thresholds (epoch seconds)
NOW=$(date +%s)
T12=$((NOW - 60*60*24*365))
T24=$((NOW - 60*60*24*365*2))

# Get commit log with author timestamp + numstat. One commit per --:: marker.
# Format: --::<unix_timestamp>
# Then numstat lines: added<TAB>removed<TAB>path
# Skip binary files (numstat = -<TAB>-).
git log --no-merges --pretty=format:'--::%at' --numstat 2>/dev/null \
| awk -v t12="$T12" -v t24="$T24" '
  BEGIN { ts=0 }
  /^--::/ {
    ts = substr($0, 5) + 0
    next
  }
  NF == 3 && $3 != "" && $1 != "-" {
    path = $3
    # Handle rename syntax: {old => new}/path or old => new
    if (path ~ /=>/) {
      # extract the new path; this is a heuristic, not perfect
      n = split(path, parts, " => ")
      if (n == 2) {
        path = parts[2]
        gsub(/[{}]/, "", path)
      }
    }
    total[path]++
    if (ts >= t12) c12[path]++
    else if (ts >= t24) c24[path]++
    else cold[path]++
  }
  END {
    for (p in total) {
      a = (p in c12) ? c12[p] : 0
      b = (p in c24) ? c24[p] : 0
      c = (p in cold) ? cold[p] : 0
      score = a*1.0 + b*0.5 + c*0.1
      printf "%s\t%.2f\t%d\t%d\t%d\n", p, score, a, b, total[p]
    }
  }
' \
| sort -t$'\t' -k2,2 -gr
