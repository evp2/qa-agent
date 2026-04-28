# code-quality — Claude Code skill

Comprehensive read-only code quality assessment. Spawns three parallel Haiku subagents (churn/complexity, architecture, dead code/duplication) and emits a timestamped Markdown report with severity-ranked, evidence-anchored findings.

## Usage

Invoke the skill with `/code-quality` followed by an optional target:

```bash
/code-quality                           # Analyze current working directory
/code-quality /path/to/local/repo       # Analyze a local repository
/code-quality https://github.com/org/repo  # Analyze a remote GitHub repository
/code-quality org/repo                  # Shorthand: expands to github.com/org/repo
```

**Examples:**

```bash
# Quick analysis of your current project
/code-quality

# Full report output to stdout
/code-quality --full-stdout

# Analyze a specific directory
/code-quality ~/projects/api-service

# Analyze a public repository
/code-quality https://github.com/anthropics/anthropic-sdk-python

# Shorthand for GitHub
/code-quality axios/axios
```

**Output:** A timestamped Markdown report (`code-quality-YYYY-MM-DD-HHMM.md`) saved to your current directory. Top Findings printed to stdout by default.

## What it does

| # | Subagent | Status | Responsibility |
|---|----------|--------|----------------|
| 1 | Churn & Complexity | **enabled** | Recency-weighted churn percentile × cyclomatic complexity → hotspot map. Bus-factor via `git blame`. |
| 2 | Architecture | **enabled** | Module map, entry points, manifests, CFN/YAML inventory. Self-identifies top-15 complexity files independently and produces a Code Smells subsection with file:line anchors. |
| 3 | Dead Code & Duplication | **enabled** | `jscpd` for clones, language-specific dead-code tools, unused CFN params/outputs, orphan YAML. LLM filter step removes obvious framework false-positives. |

## Invocation

```
/code-quality                    # current working directory
/code-quality <local-path>       # local repo path
/code-quality <github-url>       # remote — clones via gh into /tmp/, cleaned on exit
```

Optional flag: `--full-stdout` (also prints full report to stdout; default is Top Findings only).

## Output

- `./code-quality-YYYY-MM-DD-HHMM.md` (timestamped, in cwd)
- Top Findings printed to stdout

## Languages & formats

TS/JS · Python · Go · Java · Kotlin · CloudFormation (YAML/JSON) · YAML config files

## Tool requirements

**Hard required:** `git`. `gh` is required only when passing a remote URL.

**Optional (best-effort, skipped with note if missing):** `lizard`, `scc`, `jscpd`, `ts-prune`, `knip`, `vulture`, `deadcode`, `pmd`, `detekt`, `cfn-lint`, `npm`, `pip-audit`, `govulncheck`, `dependency-check` (OWASP), `go`, `mvn`, `gradle`. Run `bash lib/preflight.sh <repo>` to see what's detected.

## Findings & severity

Every finding includes an evidence anchor — a `file:line` (or `file:line-line`) source location, a manifest path with `package@version`, or a ≤3-line command-output excerpt. Findings without anchors are dropped.

Severity tiers: `critical` · `high` · `medium` · `low`. Top Findings groups by category (Architecture → Maintenance) and ranks by severity within group. Findings deduped by file path; max severity wins.

## Disclosed limitations

- Parallel execution; expect 2–6 min on medium repos (3 active subagents running concurrently).
- Subagents run on Haiku for cost efficiency.
- LLM-generated severities (architecture code smells, dead-code FP filter) are non-reproducible across runs.
- CFN/YAML orphan-config detection is heuristic and capped at medium severity.

## Layout

```
code-quality-agent/
├── SKILL.md                       # orchestrator — entry point for both runtimes
├── agents/
│   ├── churn-complexity.md
│   ├── architecture.md
│   └── dead-code.md
├── lib/
│   ├── preflight.sh               # tool detection → JSON
│   └── churn.sh                   # recency-weighted churn → TSV
└── README.md
```

## Install

### OpenClaw

```bash
ln -s ~/code-quality-agent ~/.npm-global/lib/node_modules/openclaw/skills/code-quality
```

(Adjust the OpenClaw skills directory path to wherever your install lives.)

### Claude Code

```bash
mkdir -p ~/.claude/skills
ln -s ~/code-quality-agent ~/.claude/skills/code-quality
```

After symlinking, `/code-quality` is discoverable in both runtimes.

## Permissions

Read-only on the repo. Writes only to `./code-quality-*.md` (the report) and `<repo>/.code-quality-tmp/` (cleaned on exit). PR-comment posting is a future flag.
