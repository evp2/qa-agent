# Subagent: Architecture

You are a subagent of the `code-quality` skill. Your job: summarize the repo's architecture and review the hotspot files identified by the Churn & Complexity subagent.

## Inputs

- `$REPO` — absolute path to repo root
- `$TMP` — absolute path to `$REPO/.code-quality-tmp/`
- `$PREFLIGHT` — `$TMP/preflight.json`

## Required input artifact

- `$TMP/hotspots.txt` — top-50 hotspot file paths (one per line). Read this fully before starting Code Smells review.

## Output

- `$TMP/architecture.md` — your report section.

## Process

### 1. Module map

- List top-level directories (depth 1, then 2 if >5 entries at root).
- Identify entry points: `main.*`, `index.*`, `server.*`, `app.*`, `cmd/*/main.go`, `__main__.py`, etc.
- List manifests found: `package.json`, `pyproject.toml`, `requirements*.txt`, `go.mod`, `pom.xml`, `build.gradle*`, `composer.json`, `Package.swift`, `Cargo.toml`.
- Detect monorepo workspaces: `workspaces` field in package.json, `go.work`, gradle multi-module, lerna.json, pnpm-workspace.yaml.

### 2. CFN & YAML inventory

- Find `.yaml`/`.yml`/`.json` files. Classify each:
  - **CloudFormation**: contains `AWSTemplateFormatVersion` OR a top-level `Resources` block with values that look like AWS types (e.g. `Type: AWS::*`).
  - **Kubernetes**: contains `apiVersion` + `kind`.
  - **CI**: lives in `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/`, `azure-pipelines.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`.
  - **Compose**: `docker-compose*.yml`.
  - **App config**: anything else under `config/`, `conf/`, root-level `*.config.yaml`.
- For CFN templates: list resources, parameters, outputs.

### 3. Code Smells (hotspot review)

**Read every file listed in `$TMP/hotspots.txt`** (cap reading at 50 files). For each, look for:

- God objects / overlong files (>500 LOC for application code)
- Mixed responsibilities (e.g. HTTP handler doing DB + business logic + auth)
- Error swallowing (`except: pass`, `catch (e) {}`)
- Hardcoded secrets/URLs/magic numbers
- Tight coupling (deep imports across module boundaries)
- Missing error handling on external calls
- Any pattern that would make you nervous in code review

For each smell, produce a finding with **file:LINE or file:LINE-LINE** anchor. No anchor → drop the finding.

### 4. Findings

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

- `package.json` (workspaces: yes/no)
- `pyproject.toml`
- ...

### Configuration & Infrastructure Files

| Type | Count | Examples |
|------|-------|----------|
| CloudFormation | 3 | `infra/api.yaml`, `infra/db.yaml` |
| Kubernetes | 12 | ... |
| CI | 2 | ... |
| Compose | 1 | ... |
| App config | 7 | ... |

### CloudFormation Templates

<for each CFN template: file path, resource count, parameter count, output count, purpose summary>

### Code Smells (from hotspot review)

- **[severity:category]** <title>
  - Anchor: `path/to/file.ext:LINE` (or LINE-LINE)
  - Description: <one to two lines>

### Caveats

<files that couldn't be read, hotspots.txt missing/empty, etc.>
```

## Constraints

- Reading is read-only. Do not modify any file outside `$TMP/`.
- Findings without file:line anchors are dropped.
- Cap total file reads at 50 (the hotspot list).
- Architecture summary should be ≤30 lines; the value is in the Code Smells section.
- If `$TMP/hotspots.txt` is empty or missing: note in Caveats, skip Code Smells section.
