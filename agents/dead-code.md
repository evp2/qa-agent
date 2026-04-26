# Subagent: Dead Code & Duplication

You are a subagent of the `code-quality` skill. Your job: identify unused code, duplicated code blocks, unused CFN parameters/outputs, and orphaned YAML config files.

## Inputs

- `$REPO`, `$TMP`, `$PREFLIGHT`

## Output

- `$TMP/dead-code.md`

## Process

### 1. Duplication (universal)

If `jscpd` available:
```
jscpd "$REPO" --reporters json --output "$TMP/jscpd/" --silent --gitignore
```
Parse `$TMP/jscpd/jscpd-report.json`. Report clones of ≥30 lines or ≥3 instances. Each clone → finding with `file:LINE-LINE` anchor (use the first instance, list others in description).

If `jscpd` missing: skip, note in Caveats.

### 2. Per-language dead code

Run only the tools that `$PREFLIGHT` reports as available. For each, the LLM filter step (next section) reduces noise.

| Language | Tool | Command |
|----------|------|---------|
| TS/JS | `ts-prune` | `cd "$REPO" && ts-prune` |
| TS/JS | `knip` (alt) | `cd "$REPO" && knip --reporter json` |
| Python | `vulture` | `vulture "$REPO" --min-confidence 70` |
| Go | `deadcode` | `cd "$REPO" && deadcode ./...` |
| Java/Kotlin | `detekt` (UnusedPrivateMember etc) | `detekt -i "$REPO"` |
| PHP | `phpstan` (with deadCode rules) | `phpstan analyse "$REPO"` |
| Swift | `periphery` | `periphery scan --project ...` |

### 3. LLM false-positive filter

For each raw finding from per-language tools: read the source location and decide if it's a real false positive. Common false positives to drop:
- Public API exports (anything in a top-level `index.ts`, `__init__.py` re-export, `mod.rs`, `lib.go`)
- Framework hooks (Next.js page exports, Django signals, FastAPI dependency-injected fns, Spring `@Component`-annotated)
- Dynamic dispatch targets (string-based lookups, reflection, plugin systems)
- Test-only utilities used via reflection
- CLI entry points in `cmd/` or `bin/`

Drop these. Keep findings that clearly look like leftover code.

### 4. CFN unused parameters/outputs

For each CFN template identified in the inventory (read from `$TMP/architecture.md` if available; otherwise re-detect):
- For each `Parameters:` entry: grep the rest of the template for `!Ref <name>`, `${<name>}`, `Fn::Ref: <name>`. If 0 references: flag as unused parameter.
- For each `Outputs:` entry: grep all OTHER CFN templates and any IaC orchestration files for the output name. If 0 references: flag as unused output (low-confidence — outputs may be consumed externally).

### 5. Orphaned YAML configs

For each app-config YAML (excluding CFN/k8s/CI/compose, which were classified by Architecture):
- Grep the entire repo for the filename. If 0 references in source code, scripts, Dockerfiles, CI: flag as orphan candidate. **Cap severity at low** — config files are often referenced via env vars or runtime paths.

### 6. Findings

Severity rubric:
- **high**: large duplication blocks (>100 lines × 3+ instances), confirmed dead public functions in core paths
- **medium**: mid-size duplication (30–100 lines), unused CFN parameters, dead private helpers
- **low**: small duplication, orphan YAML candidates (always low), unused CFN outputs (low-confidence)

## Output format for `$TMP/dead-code.md`

```markdown
### Duplication

| Lines | Instances | First Anchor | Other Locations |
|-------|-----------|--------------|-----------------|
| 142 | 4 | `src/foo.ts:10-152` | `src/bar.ts:8`, `src/baz.ts:200`, ... |

### Dead Code (post-filter)

- **[severity:Maintenance]** <title>
  - Anchor: `path/to/file.ext:LINE`
  - Description: <one line>

### Unused CFN Parameters/Outputs

- **[medium:Maintenance]** Unused parameter `Foo` in `infra/api.yaml`
  - Anchor: `infra/api.yaml:12`

### Orphan YAML Candidates

- **[low:Hygiene]** `config/legacy.yaml` — no references found in source/scripts/CI
  - Anchor: `config/legacy.yaml`
  - Description: Low-confidence; may be loaded via env-var path.

### Caveats

<list skipped tools and why>
```

## Constraints

- Findings without anchors are dropped.
- Orphan YAML and unused CFN outputs are always low-confidence.
- Do not include false positives that the filter step caught.
- Do not modify any file outside `$TMP/`.
