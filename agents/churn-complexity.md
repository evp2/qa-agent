# Subagent: Churn & Complexity

You are a subagent of the `code-quality` skill. Your job: produce churn/complexity/bus-factor analysis and generate `$TMP/hotspots.txt` for the Architecture subagent to consume.

## Inputs (substituted by orchestrator)

- `$REPO` — absolute path to repo root
- `$TMP` — absolute path to `$REPO/.code-quality-tmp/`
- `$PREFLIGHT` — `$TMP/preflight.json` listing available tools

## Outputs

- `$TMP/hotspots.txt` — top-50 file paths (relative to repo root), one per line, ordered by hotspot score descending. **No headers, no commentary.**
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

Write top 50 paths (relative, no `./` prefix) to `$TMP/hotspots.txt`, one per line, ordered by score descending. Exclude generated/vendored paths matching: `node_modules/`, `vendor/`, `dist/`, `build/`, `.next/`, `target/`, `*.min.js`, `*.lock`, `package-lock.json`, `yarn.lock`, `poetry.lock`, `go.sum`.

### 4. Bus-factor

For each file in the top 100 by churn: run `git -C "$REPO" log --pretty=format:'%an' -- <file> | sort | uniq -c | sort -rn | head -1`. If top author owns ≥80% of commits AND the file has ≥10 commits: flag as bus-factor risk.

### 5. Findings

Generate findings for `$TMP/churn.md`. Each finding must have an evidence anchor (file path is sufficient for churn/bus-factor; file:line preferred for complexity if you can identify the worst function).

Severity rubric:
- **critical**: hotspot in top 1% AND bus-factor risk AND file >500 LOC
- **high**: hotspot in top 5%, OR bus-factor risk on file with >10 commits
- **medium**: high-churn (top 5%) without complexity overlay, OR complexity-only outlier
- **low**: notable but not actionable

## Output format for `$TMP/churn.md`

```markdown
### Hotspot Map

| Rank | File | Churn %ile | Complexity %ile | Hotspot Score | Notes |
|------|------|------------|-----------------|---------------|-------|
| 1 | `src/foo.py` | 99 | 95 | 0.94 | Top hotspot |
| ... |

### Bus-Factor Risks

- **[high]** `src/payments/processor.py` — 92% of commits by single author over 47 commits. Knowledge concentration risk.
  - Anchor: `src/payments/processor.py`

### Findings

- **[severity:category]** <title>
  - Anchor: `<file:line>` or `<file>`
  - Description: <one line>
  - Category: Architecture (for hotspots/bus-factor)

### Caveats

<note any tools that were skipped — e.g. "Complexity skipped: neither lizard nor scc installed.">
```

## Constraints

- Do not include findings without an anchor.
- Do not write commentary outside the structured sections above.
- Do not modify any file outside `$TMP/`.
- If `git log` fails (shallow clone, no history): note in Caveats and produce a minimal hotspots.txt based on file size only.
