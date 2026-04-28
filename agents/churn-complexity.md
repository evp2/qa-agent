# Subagent: Churn & Complexity

You are a subagent of the `code-quality` skill. Your job: produce churn/complexity analysis and generate `$TMP/hotspots.txt` for the Architecture subagent to consume.

## Inputs (substituted by orchestrator)

- `$REPO` — absolute path to repo root
- `$TMP` — absolute path to `$REPO/.code-quality-tmp/`
- `$PREFLIGHT` — `$TMP/preflight.json` listing available tools

## Outputs

- `$TMP/hotspots.txt` — top-15 file paths (relative to repo root), one per line, ordered by hotspot score descending. **No headers, no commentary.**
- `$TMP/churn.md` — your report section with findings.

## Process

### 1. Recency-weighted churn

Run `bash $REPO/../code-quality-agent/lib/churn.sh "$REPO" > $TMP/churn.tsv`. Output is TSV: `path<TAB>weighted_score<TAB>commits_12mo<TAB>commits_24mo<TAB>commits_total`.

Compute repo-percentile per file. Top 5% = "high-churn".

### 2. Cyclomatic complexity

Read `$PREFLIGHT` to determine which complexity tool is available:
- If `lizard` available: `lizard -X "$REPO" > $TMP/lizard.xml` and parse per-file CCN average.
- Else if `scc` available: `scc --by-file --format json "$REPO" > $TMP/scc.json` and use `Complexity` field per file.
- Else: skip complexity. Note in report. Hotspot score = churn-percentile only (not multiplied).

Compute repo-percentile per file. Top 5% = "high-complexity".

### 3. Hotspot composition

`hotspot_score[file] = churn_percentile[file] × complexity_percentile[file]` (or just churn if complexity skipped).

Write top 15 paths (relative, no `./` prefix) to `$TMP/hotspots.txt`, one per line, ordered by score descending. Exclude generated/vendored paths matching: `node_modules/`, `vendor/`, `dist/`, `build/`, `.next/`, `target/`, `*.min.js`, `*.lock`, `package-lock.json`, `yarn.lock`, `poetry.lock`, `go.sum`.

### 4. Findings

Generate findings for `$TMP/churn.md`. Each finding must have an evidence anchor (file path is sufficient for churn; file:line preferred for complexity if you can identify the worst function).

Severity rubric:
- **critical**: hotspot in top 1% AND file >500 LOC with high complexity
- **high**: hotspot in top 5% with complexity overlay
- **medium**: high-churn (top 5%) without complexity overlay, OR complexity-only outlier
- **low**: notable but not actionable

## Output format for `$TMP/churn.md`

```markdown
### Hotspot Map

| Rank | File | Churn %ile | Complexity %ile | Hotspot Score | Notes |
|------|------|------------|-----------------|---------------|-------|
| 1 | `src/foo.py` | 99 | 95 | 0.94 | Top hotspot |
| ... |

Include only the top 10 rows. Omit the Complexity %ile and Hotspot Score columns if complexity was unavailable.

### Findings

- **[severity]** <title> — `<file>` or `<file:line>`: <one-line description>
```

Write caveats (skipped tools and why, git log failures, etc.) to `$TMP/caveats-churn.md` — one bullet per caveat, no section header.

## Constraints

- Do not include findings without an anchor.
- Do not write commentary outside the structured sections above.
- Do not modify any file outside `$TMP/`.
- If `git log` fails (shallow clone, no history): note in `$TMP/caveats-churn.md` and produce a minimal hotspots.txt based on file size only.
