# code-quality — Claude Code skill

> Get a full code quality report on any project in under 6 minutes — no config, 3 parallel Haiku subagents.

Three parallel AI subagents tear through your codebase simultaneously: one maps churn hotspots, one audits architecture, one hunts dead code. The result is a timestamped Markdown report with severity-ranked findings, every one anchored to a file and line number.

---

## Demo

```
## Top Findings

### Architecture
- **[high]** `src/api/routes.js:1-312` — monolithic route file, 312 lines, 18 exported handlers. Extract into feature modules.
- **[high]** `lib/db.js:44` — circular dependency: db → cache → db. Breaks test isolation.

### Maintenance
- **[medium]** `src/utils/format.ts:12-67` — duplicated in `src/helpers/display.ts:8-61` (87% similarity via jscpd)
- **[medium]** `workers/legacy.py` — 0 references found; appears unreachable since commit a3f9c2b

### Churn Hotspots
- **[high]** `src/auth/middleware.js` — top 5% churn, cyclomatic complexity 24. High bus-factor risk (1 author, 89% of commits).
```

*Full report saved to `./code-quality-2026-04-30-1142.md`*

---

## Usage

```bash
/code-quality                              # Analyze current working directory
/code-quality /path/to/local/repo          # Analyze a local repository
/code-quality https://github.com/org/repo  # Analyze a remote GitHub repository
/code-quality org/repo                     # Shorthand for GitHub repos
```

**Output:** A timestamped Markdown report (`code-quality-YYYY-MM-DD-HHMM.md`) saved to your current directory. Top Findings printed to stdout by default.

Optional flag: `--full-stdout` — print the full report to stdout instead of just Top Findings.

---

## What it does

Three subagents run in parallel, each with a focused responsibility:

| Subagent | What it finds |
|----------|---------------|
| **Churn & Complexity** | Recency-weighted churn × cyclomatic complexity → hotspot map. Bus-factor risk via `git blame`. |
| **Architecture** | Module map, entry points, dependency graph, CFN/YAML inventory. Code smells with `file:line` anchors. |
| **Dead Code & Duplication** | Clone detection via `jscpd`, unused exports, orphan YAML, unused CloudFormation params. LLM filter removes framework false-positives. |

Every finding includes an evidence anchor — a `file:line` location, a `package@version` from a manifest, or a command-output excerpt. Findings without anchors are dropped. Severity tiers: `critical` · `high` · `medium` · `low`.

---

## Languages & formats

TS/JS · Python · Go · Java · Kotlin · CloudFormation (YAML/JSON) · YAML config files

---

## Install

### Claude Code

```bash
mkdir -p ~/.claude/skills
ln -s ~/code-quality-agent ~/.claude/skills/code-quality
```

### OpenClaw

```bash
ln -s ~/code-quality-agent ~/.npm-global/lib/node_modules/openclaw/skills/code-quality
```

After symlinking, `/code-quality` is available in your session.

---

<details>
<summary>Tool requirements</summary>

**Hard required:** `git`. `gh` is required only when passing a remote URL.

**Optional (best-effort, skipped with note if missing):** `lizard`, `scc`, `jscpd`, `ts-prune`, `knip`, `vulture`, `deadcode`, `pmd`, `detekt`, `cfn-lint`, `npm`, `pip-audit`, `govulncheck`, `dependency-check` (OWASP), `go`, `mvn`, `gradle`.

Run `bash lib/preflight.sh <repo>` to see what's detected in your environment.

</details>

<details>
<summary>Limitations</summary>

- Parallel execution; expect 2–6 min on medium repos.
- Subagents run on Haiku for cost efficiency.
- LLM-generated severities are non-reproducible across runs.
- CFN/YAML orphan-config detection is heuristic and capped at medium severity.

</details>

<details>
<summary>Repo layout</summary>

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

</details>

---

## Permissions

Read-only on the repo. Writes only to `./code-quality-*.md` (the report) and `<repo>/.code-quality-tmp/` (cleaned on exit).
