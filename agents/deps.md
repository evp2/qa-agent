# Subagent: Dependency Health

You are a subagent of the `code-quality` skill. Your job: identify outdated dependencies and known CVEs across all manifests in the repo (multi-language aware).

## Inputs

- `$REPO`, `$TMP`, `$PREFLIGHT`

## Output

- `$TMP/deps.md`

## Process

### 1. Find ALL manifests

Walk the repo (excluding `node_modules/`, `vendor/`, `dist/`, `build/`, `.git/`) and collect every:
- `package.json` (note: each one — monorepos have many)
- `pyproject.toml`, `requirements*.txt`, `Pipfile`, `setup.py`, `setup.cfg`
- `go.mod`
- `pom.xml`, `build.gradle`, `build.gradle.kts`
- `composer.json`
- `Package.swift`, `Cargo.toml`

Detect monorepo workspace files (`workspaces` in root package.json, `go.work`, `pnpm-workspace.yaml`, gradle settings) and process all child manifests.

### 2. Lockfile presence

For each manifest, check for the corresponding lockfile:
- `package.json` → `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml`
- `pyproject.toml` → `poetry.lock` / `uv.lock`; `requirements*.txt` is itself a pin
- `go.mod` → `go.sum`
- `pom.xml` → no separate lock; uses transitively resolved versions
- `composer.json` → `composer.lock`

If a manifest has no lock and the language requires one for CVE scanning: skip CVE check for that manifest, note in Caveats with which manifest path.

### 3. CVE scans (per language, if tool available)

| Manifest | Tool | Command | Output |
|----------|------|---------|--------|
| `package.json` (with lock) | `npm audit` | `cd <dir> && npm audit --json` | parse JSON |
| `pyproject.toml` / `requirements*.txt` | `pip-audit` | `pip-audit -r <file> -f json` or `pip-audit --pyproject <file> -f json` | parse |
| `go.mod` | `govulncheck` | `cd <dir> && govulncheck -json ./...` | parse |
| `pom.xml` / `build.gradle*` | `dependency-check` (OWASP) | `dependency-check --scan <dir> --format JSON --out <out>` | parse |
| `composer.json` | `composer audit` | `cd <dir> && composer audit --format=json` | parse |
| `Package.swift` | none | list pinned deps only; note caveat | — |

If tool missing: skip, note in Caveats.

### 4. Outdated checks (per language, if tool available)

| Manifest | Command |
|----------|---------|
| `package.json` | `cd <dir> && npm outdated --json` |
| Python | `pip list --outdated --format json` (in correct env) — best-effort; often skipped |
| `go.mod` | `cd <dir> && go list -m -u -json all` |
| `pom.xml` | `mvn versions:display-dependency-updates` |
| `build.gradle*` | `gradle dependencyUpdates -q` (requires plugin) — best-effort |
| `composer.json` | `cd <dir> && composer outdated --format=json` |

Outdated-only findings are downgraded if no CVE attached.

### 5. Findings

Severity rubric:
- **critical**: any CVE labeled critical or high
- **high**: any CVE labeled medium
- **medium**: CVE low, OR deprecated package (no CVE), OR major-version-outdated with maintenance abandoned (last release >2y)
- **low**: minor/patch outdated, no CVE

Each finding's anchor: the manifest path **plus** `package@version` inline in the title.

## Output format for `$TMP/deps.md`

```markdown
### Manifest Inventory

| Manifest | Language | Lockfile present | Scanned |
|----------|----------|------------------|---------|
| `package.json` | npm | yes (package-lock.json) | yes |
| `services/api/pyproject.toml` | python | yes (poetry.lock) | yes |
| `services/worker/go.mod` | go | yes (go.sum) | yes |
| `infra/composer.json` | php | no | no — composer.lock missing |

### CVE Findings

| Severity | Package | Version | CVE | Manifest | Fix Version |
|----------|---------|---------|-----|----------|-------------|
| critical | lodash | 4.17.10 | CVE-2019-10744 | `package.json` | 4.17.12 |
| ...

### Outdated (no CVE)

| Package | Current | Latest | Manifest | Notes |
|---------|---------|--------|----------|-------|
| react | 17.0.2 | 19.0.0 | `package.json` | major behind |
| ...

### Findings

- **[critical:Security]** `lodash@4.17.10` vulnerable to prototype pollution (CVE-2019-10744)
  - Anchor: `package.json` — `lodash@4.17.10`
  - Description: Fix available in 4.17.12.

### Caveats

<list manifests skipped due to missing lockfiles or missing tools>
```

## Constraints

- Findings without manifest anchor + package@version are dropped.
- Multi-language aware: do not stop at first manifest type found.
- Do not run any package install or update.
- Do not modify any file outside `$TMP/`.
