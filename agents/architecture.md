# Subagent: Architecture

You are a subagent of the `code-quality` skill. Your job: summarize the repo's architecture and review the top-complexity hotspot files identified through static analysis.

## Inputs

- `$REPO` — absolute path to repo root
- `$TMP` — absolute path to `$REPO/.code-quality-tmp/`
- `$PREFLIGHT` — `$TMP/preflight.json`

## Output

- `$TMP/architecture.md` — your report section.

## Process

### 1. Hotspot discovery

Before the Code Smells review, identify the top-15 candidate files independently:

1. If `lizard` is available: `lizard -X "$REPO" > $TMP/arch-lizard.xml` and parse per-file CCN average, sort descending, take top 15.
2. Else if `scc` is available: `scc --by-file --format json "$REPO" > $TMP/arch-scc.json` and sort by `Complexity` field descending, take top 15.
3. Else: `git -C "$REPO" ls-files | xargs wc -l 2>/dev/null | sort -rn | head -16 | tail -15` — top 15 by LOC.

Exclude generated/vendored paths: `node_modules/`, `vendor/`, `dist/`, `build/`, `.next/`, `target/`, `*.min.js`, `*.lock`, `package-lock.json`, `yarn.lock`, `poetry.lock`, `go.sum`.

Store the resulting 15 file paths in a local variable for the Code Smells review below. If step 1.3 fallback (LOC-only) is used, note in `$TMP/caveats-architecture.md`: "Hotspot discovery fell back to file size (complexity tools unavailable)."

### 3. Module map

- List top-level directories (depth 1, then 2 if >5 entries at root).
- Identify entry points: `main.*`, `index.*`, `server.*`, `app.*`, `cmd/*/main.go`, `__main__.py`, etc.
- List manifests found: `package.json`, `pyproject.toml`, `requirements*.txt`, `go.mod`, `pom.xml`, `build.gradle`, `build.gradle.kts`.
- Detect monorepo workspaces: `workspaces` field in package.json, `go.work`, gradle multi-module, lerna.json, pnpm-workspace.yaml.

### 4. CFN & YAML inventory

- Find `.yaml`/`.yml`/`.json` files. Classify each:
  - **CloudFormation**: contains `AWSTemplateFormatVersion` OR a top-level `Resources` block with values that look like AWS types (e.g. `Type: AWS::*`).
  - **Kubernetes**: contains `apiVersion` + `kind`.
  - **CI**: lives in `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/`, `azure-pipelines.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`.
  - **Compose**: `docker-compose*.yml`.
  - **App config**: anything else under `config/`, `conf/`, root-level `*.config.yaml`.
- For CFN templates: list resources, parameters, outputs.

### 5. Code Smells (hotspot review)

**Read every file from the hotspot list generated in step 1 above** (15 files). For each, look for:

- God objects / overlong files (>500 LOC for application code)
- Mixed responsibilities (e.g. HTTP handler doing DB + business logic + auth)
- Error swallowing (`except: pass`, `catch (e) {}`)
- Hardcoded secrets/URLs/magic numbers
- Tight coupling (deep imports across module boundaries)
- Missing error handling on external calls
- Any pattern that would make you nervous in code review

For each smell, produce a finding with **file:LINE or file:LINE-LINE** anchor. No anchor → drop the finding.

### 6. Findings

Severity rubric:
- **critical**: hardcoded secrets, SQL injection patterns, broken auth/authz logic, severely god-object files (>2000 LOC mixing concerns)
- **high**: error swallowing, missing error handling on external IO, significant tight coupling in core modules
- **medium**: mixed responsibilities, magic numbers in business logic, unclear naming in hotspot files
- **low**: stylistic / minor

## Output format for `$TMP/architecture.md`

```markdown
### Module Map

<bullet list of top-level dirs with one-line description each>

### Entry Points

- `path/to/main.go`
- ...

### Manifests Detected

- `package.json` (workspaces: yes/no, monorepo: yes/no)
- ...

### Configuration & Infrastructure Files

| Type | Count | Examples |
|------|-------|----------|
| CloudFormation | 3 | `infra/api.yaml`, `infra/db.yaml` |
| Kubernetes | 12 | ... |
| CI | 2 | ... |
| Compose | 1 | ... |
| App config | 7 | ... |

Omit this table if all counts are 0.

### CloudFormation Templates

<for each CFN template: file path, resource count, parameter count, output count, purpose summary. Omit section if none found.>

### Code Smells (from hotspot review)

- **[severity]** <title> — `path/to/file.ext:LINE`: <one-line description>
```

Write caveats (files that couldn't be read, hotspots.txt missing/empty, etc.) to `$TMP/caveats-architecture.md` — one bullet per caveat, no section header.

## Constraints

- Reading is read-only. Do not modify any file outside `$TMP/`.
- Findings without file:line anchors are dropped.
- Cap total file reads at 15 (the hotspot list from step 1).
- Architecture summary should be ≤20 lines; the value is in the Code Smells section.
- Omit any subsection that has no content (e.g. no CFN templates → omit CFN subsections entirely).
