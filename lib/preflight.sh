#!/usr/bin/env bash
# preflight.sh — detect available tools, emit JSON to stdout.
# Usage: bash preflight.sh <repo-path>
# Hard-required: git. Everything else: optional, marked missing if absent.

set -u

REPO="${1:-}"
if [[ -z "$REPO" ]]; then
  echo "usage: preflight.sh <repo-path>" >&2
  exit 2
fi

have() { command -v "$1" >/dev/null 2>&1; }
ver() {
  # best-effort version string (first line, first match-ish)
  "$@" 2>/dev/null | head -1 | tr -d '\n' | sed 's/"/\\"/g'
}

tool_entry() {
  local name="$1" present="$2" version="$3" install_hint="$4" purpose="$5"
  printf '    {"name":"%s","present":%s,"version":"%s","install_hint":"%s","purpose":"%s"}' \
    "$name" "$present" "$version" "$install_hint" "$purpose"
}

declare -a entries=()

# --- Hard requirements ---
if have git; then
  entries+=("$(tool_entry "git" "true" "$(ver git --version)" "" "VCS — required")")
else
  echo '{"error":"git not installed — hard requirement","present":false}'
  exit 1
fi

# gh — only required when remote URL passed; preflight just records presence
if have gh; then
  entries+=("$(tool_entry "gh" "true" "$(ver gh --version)" "" "GitHub clone for remote repos")")
else
  entries+=("$(tool_entry "gh" "false" "" "https://cli.github.com/" "GitHub clone for remote repos")")
fi

# --- Complexity ---
if have lizard; then
  entries+=("$(tool_entry "lizard" "true" "$(ver lizard --version)" "" "Cyclomatic complexity (preferred)")")
else
  entries+=("$(tool_entry "lizard" "false" "" "pip install lizard" "Cyclomatic complexity (preferred)")")
fi

if have scc; then
  entries+=("$(tool_entry "scc" "true" "$(ver scc --version)" "" "LOC + complexity fallback")")
else
  entries+=("$(tool_entry "scc" "false" "" "https://github.com/boyter/scc" "LOC + complexity fallback")")
fi

# --- Duplication ---
if have jscpd; then
  entries+=("$(tool_entry "jscpd" "true" "$(ver jscpd --version)" "" "Duplication detection (universal)")")
else
  entries+=("$(tool_entry "jscpd" "false" "" "npm i -g jscpd" "Duplication detection (universal)")")
fi

# --- Dead code, per language ---
if have ts-prune; then
  entries+=("$(tool_entry "ts-prune" "true" "$(ver ts-prune --version)" "" "TS/JS dead exports")")
else
  entries+=("$(tool_entry "ts-prune" "false" "" "npm i -g ts-prune" "TS/JS dead exports")")
fi

if have knip; then
  entries+=("$(tool_entry "knip" "true" "$(ver knip --version)" "" "TS/JS unused (alt to ts-prune)")")
else
  entries+=("$(tool_entry "knip" "false" "" "npm i -g knip" "TS/JS unused (alt to ts-prune)")")
fi

if have vulture; then
  entries+=("$(tool_entry "vulture" "true" "$(ver vulture --version)" "" "Python dead code")")
else
  entries+=("$(tool_entry "vulture" "false" "" "pip install vulture" "Python dead code")")
fi

if have deadcode; then
  entries+=("$(tool_entry "deadcode" "true" "$(ver deadcode -h 2>&1 || true)" "" "Go dead code")")
else
  entries+=("$(tool_entry "deadcode" "false" "" "go install golang.org/x/tools/cmd/deadcode@latest" "Go dead code")")
fi

if have pmd; then
  entries+=("$(tool_entry "pmd" "true" "$(ver pmd --version 2>&1 | head -1)" "" "Java static analysis incl. dead code")")
else
  entries+=("$(tool_entry "pmd" "false" "" "https://pmd.github.io/" "Java static analysis incl. dead code")")
fi

if have detekt; then
  entries+=("$(tool_entry "detekt" "true" "$(ver detekt --version)" "" "Kotlin static analysis incl. dead code")")
else
  entries+=("$(tool_entry "detekt" "false" "" "https://detekt.dev/" "Kotlin static analysis incl. dead code")")
fi

# --- CFN ---
if have cfn-lint; then
  entries+=("$(tool_entry "cfn-lint" "true" "$(ver cfn-lint --version)" "" "CloudFormation linting")")
else
  entries+=("$(tool_entry "cfn-lint" "false" "" "pip install cfn-lint" "CloudFormation linting")")
fi

# --- CVE / outdated ---
if have npm; then
  entries+=("$(tool_entry "npm" "true" "$(ver npm --version)" "" "npm audit + npm outdated")")
else
  entries+=("$(tool_entry "npm" "false" "" "https://nodejs.org/" "npm audit + npm outdated")")
fi

if have pip-audit; then
  entries+=("$(tool_entry "pip-audit" "true" "$(ver pip-audit --version)" "" "Python CVE scanning")")
else
  entries+=("$(tool_entry "pip-audit" "false" "" "pip install pip-audit" "Python CVE scanning")")
fi

if have govulncheck; then
  entries+=("$(tool_entry "govulncheck" "true" "$(ver govulncheck -version 2>&1 | head -1)" "" "Go CVE scanning")")
else
  entries+=("$(tool_entry "govulncheck" "false" "" "go install golang.org/x/vuln/cmd/govulncheck@latest" "Go CVE scanning")")
fi

if have dependency-check; then
  entries+=("$(tool_entry "dependency-check" "true" "$(ver dependency-check --version)" "" "Java/Kotlin CVE scanning (OWASP)")")
else
  entries+=("$(tool_entry "dependency-check" "false" "" "https://github.com/jeremylong/DependencyCheck" "Java/Kotlin CVE scanning (OWASP)")")
fi

if have go; then
  entries+=("$(tool_entry "go" "true" "$(ver go version)" "" "Go toolchain (for go list)")")
else
  entries+=("$(tool_entry "go" "false" "" "https://go.dev/doc/install" "Go toolchain (for go list)")")
fi

if have mvn; then
  entries+=("$(tool_entry "mvn" "true" "$(ver mvn --version | head -1)" "" "Maven (for outdated checks)")")
else
  entries+=("$(tool_entry "mvn" "false" "" "https://maven.apache.org/" "Maven (for outdated checks)")")
fi

if have gradle; then
  entries+=("$(tool_entry "gradle" "true" "$(ver gradle --version | head -1)" "" "Gradle (for outdated checks)")")
else
  entries+=("$(tool_entry "gradle" "false" "" "https://gradle.org/" "Gradle (for outdated checks)")")
fi

# --- Emit JSON ---
{
  echo '{'
  echo '  "repo": "'"$REPO"'",'
  echo '  "tools": ['
  for i in "${!entries[@]}"; do
    if [[ $i -lt $((${#entries[@]} - 1)) ]]; then
      echo "${entries[$i]},"
    else
      echo "${entries[$i]}"
    fi
  done
  echo '  ]'
  echo '}'
}
