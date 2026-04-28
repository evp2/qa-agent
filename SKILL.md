---
name: code-quality
description: Comprehensive read-only code quality assessment. Spawns 3 parallel Haiku subagents (churn/complexity, architecture, dead code/duplication) and emits a timestamped Markdown report with severity-ranked, evidence-anchored findings. Supports local paths and remote GitHub URLs (incl. private repos via gh).
model: sonnet
---

# code-quality

You are the **orchestrator** for a code quality assessment. Spawn three subagents sequentially (each Haiku), collect their outputs, assemble a single Markdown report.

## Invocation

```
/code-quality                    # current working directory
/code-quality <local-path>       # local repo path
/code-quality <github-url>       # remote — clones via `gh repo clone`
```

Optional flag: `--full-stdout` (also print full report to stdout; default is Top Findings only).

## Step 1 — Resolve target

1. If argument is a URL (matches `^https?://github.com/` or `^git@github.com:`):
   - Verify `gh auth status` succeeds. If not, abort with: `gh CLI is not authenticated. Run: gh auth login`.
   - Clone to `/tmp/code-quality-<sha1-of-url-first-8>/`.
   - Set `REPO=<clone-path>`. Register cleanup trap.
2. If argument is a local path: validate it's a directory containing `.git/`. Set `REPO=<abs-path>`.
3. If no argument: use cwd. Validate `.git/` exists.
4. Set `REPORT=$PWD/code-quality-$(date -u +%Y-%m-%d-%H%M).md`.
5. Set `TMP=$REPO/.code-quality-tmp/` and create it. Register cleanup trap.

## Step 2 — Preflight (best-effort)

Run `bash lib/preflight.sh "$REPO"` to detect available tools. Output goes to `$TMP/preflight.json`. Hard requirements: `git` only. Everything else: skipped with note if absent.

If `git` missing: abort.

## Step 3 — Spawn subagents (parallel)

All three subagents run independently with no inter-agent dependencies. Create a task list to track completion:

- [ ] churn-complexity
- [ ] architecture
- [ ] dead-code

**In Claude Code:** call the `Agent` tool **three times in a single response** (parallel execution):

1. Agent 1 (churn-complexity):
   - subagent_type: "general-purpose"
   - model: "haiku"
   - prompt = full contents of `agents/churn-complexity.md` with vars substituted: `$REPO`, `$TMP`, `$PREFLIGHT=$TMP/preflight.json`

2. Agent 2 (architecture):
   - subagent_type: "general-purpose"
   - model: "haiku"
   - prompt = full contents of `agents/architecture.md` with vars substituted: `$REPO`, `$TMP`, `$PREFLIGHT=$TMP/preflight.json`

3. Agent 3 (dead-code):
   - subagent_type: "general-purpose"
   - model: "haiku"
   - prompt = full contents of `agents/dead-code.md` with vars substituted: `$REPO`, `$TMP`, `$PREFLIGHT=$TMP/preflight.json`

As each agent completes, mark the corresponding task complete. Wait for all three to complete before proceeding to Step 4.

**In OpenClaw:** call `sessions_spawn` three times without awaiting each one individually. Then await all three results. For each, use `model: "haiku"`, `context: "isolated"`, prompt = same as above. Mark tasks complete as responses arrive.

Each subagent writes its output to `$TMP/` (e.g., `$TMP/churn.md`, `$TMP/architecture.md`, `$TMP/dead-code.md`). The orchestrator does NOT include subagent narrative in its own context — it only reads the resulting files when assembling the report in Step 4.

## Step 4 — Assemble report

Build the report file at `$REPORT` with this structure:

```markdown
# Code Quality Report — <repo-basename> — <ISO timestamp UTC>

## Top Findings

<deduplicated, grouped by category, ranked by severity within group>

## Architecture

<contents of $TMP/architecture.md>

## Churn & Complexity

<contents of $TMP/churn.md>

## Dead Code & Duplication

<contents of $TMP/dead-code.md>

## Limitations & Caveats

<merge bullets from $TMP/caveats-architecture.md, $TMP/caveats-churn.md, $TMP/caveats-dead-code.md (skip any file that doesn't exist), then append the fixed bullets below>
- LLM-generated severities are non-reproducible across runs.

## Tool Versions & Skipped Checks

<rendered from $TMP/preflight.json — table: tool | version | status (ok/missing/skipped) | install hint. Omit rows where status=ok and tool is not relevant to this repo's language stack.>
```

### Top Findings assembly rules

1. Read findings from each subagent's section. Each finding has: `severity`, `category`, `title`, `evidence_anchor`, `description`.
2. Categories (in display order): **Architecture**, **Maintenance**.
   - Architecture ← Architecture (code smells, structural issues), Churn & Complexity (hotspots, complexity outliers).
   - Maintenance ← Dead Code & Duplication.
3. Dedupe by `evidence_anchor` (file path or file:line). When duplicate: max severity wins, descriptions merged.
4. Within each category: sort by severity (critical → low), then alphabetic by file.
5. Drop any finding lacking an evidence anchor — orchestrator's responsibility to enforce.
6. Render each finding as:
   ```
   - **[severity]** <title> — `<anchor>`
     <one-line description>
   ```

## Step 5 — Output

1. Print **Top Findings section only** to stdout, plus a one-line footer: `Full report: <REPORT>`.
2. If `--full-stdout` flag was set: also print the entire report.
3. Write the full report to `$REPORT`.

## Step 6 — Cleanup

- Remove `$TMP`.
- If repo was cloned to `/tmp/code-quality-<hash>/`: remove the clone.
- Both must run on success AND failure (trap EXIT in shell, try/finally in code path).

## Universal evidence-anchor rule

**Drop any finding without one of:**
- `path/to/file.ext:LINE` or `path/to/file.ext:LINE-LINE` (source-anchored)
- `path/to/manifest` plus inline `package@version` (dependency-anchored)
- A ≤3-line fenced excerpt of command output (tool-anchored)

The orchestrator filters subagent outputs against this rule before report assembly. Any subagent that returns findings without anchors gets a single retry with the instruction to add anchors; if still missing, those findings are dropped and the report's Limitations section gets a note.
