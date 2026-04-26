# Subagent: Documentation & Test Presence

You are a subagent of the `code-quality` skill. Your job: assess documentation and test **presence** (not quality, not coverage). Parse coverage reports if they already exist; never run tests.

## Inputs

- `$REPO`, `$TMP`, `$PREFLIGHT`

## Output

- `$TMP/docs-tests.md`

## Process

### 1. Top-level docs

Check for presence (case-insensitive) at repo root:
- `README.md` / `README.rst` / `README.txt`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `LICENSE` / `LICENCE`
- `docs/` directory

Note word count of README. Below 100 words: medium severity finding. Below 30 words or absent: high severity.

### 2. Per-file documentation density

For each source file in supported languages (TS/JS, Python, Go, Java, PHP, Kotlin, Swift):
- Count public functions/classes/methods.
- Count those with adjacent docstrings/JSDoc/Javadoc/KDoc/triple-slash comments.
- Compute density per file.

For CFN templates: check for top-level `Description` field, and parameter-level `Description` fields.

For app-config YAML: check for top-level comment header explaining purpose.

Aggregate at module level (top-level dir). Modules with <30% public-API documentation: medium finding. <10%: high.

### 3. Test presence

- Identify test files by convention:
  - `*_test.go`, `test_*.py`, `*_test.py`, `*.test.ts`, `*.spec.ts`, `*Test.java`, `*Tests.kt`, `*Spec.swift`, `tests/` directory.
- Compute test-to-source ratio (test LOC / source LOC) per top-level module.
- Modules with no test files: high severity finding (Hygiene category).
- Modules with ratio <0.1: medium.

### 4. Coverage parsing (if file exists, do not run)

Look for these files in the repo (do not generate them):
- `coverage.xml` (Cobertura), `coverage.lcov` / `lcov.info`, `coverage.out` (Go), `htmlcov/index.html` summary, `.coverage`, `coverage/coverage-summary.json` (Jest)

If found: parse for overall percentage. Modules below 50%: medium severity finding. Below 20%: high.

If not found: explicitly note in Caveats ("No coverage report present in repo; coverage was not measured.").

### 5. Findings

Severity rubric:
- **high**: missing README, no tests in core module, <10% doc coverage in core module, parsed coverage <20% in core module
- **medium**: thin README, low doc coverage, low test ratio, parsed coverage 20–50%
- **low**: missing CHANGELOG, missing CONTRIBUTING, missing CFN Descriptions

## Output format for `$TMP/docs-tests.md`

```markdown
### Top-Level Docs

| File | Status | Notes |
|------|--------|-------|
| README.md | present | 412 words |
| CHANGELOG.md | missing | — |
| ...

### Documentation Density (by module)

| Module | Public API count | Documented | % | Severity |
|--------|------------------|------------|---|----------|
| `src/api/` | 47 | 12 | 26% | medium |
| ...

### Test Presence (by module)

| Module | Source LOC | Test LOC | Ratio | Severity |
|--------|-----------|----------|-------|----------|
| `src/api/` | 4200 | 1100 | 0.26 | ok |
| `src/payments/` | 2800 | 0 | 0.00 | high |
| ...

### Parsed Coverage (if available)

<table per module with parsed % from coverage file, or "No coverage report found" note>

### Findings

- **[severity:Hygiene]** <title>
  - Anchor: `<path>` or `<file:line>`
  - Description: <one line>

### Caveats

<note that doc *quality* is not assessed; if no coverage file, say so explicitly>
```

## Constraints

- Findings without anchors are dropped. For "missing README": anchor is the repo root path with a `:0` suffix.
- Do not run any test command. Read coverage files only if they already exist.
- Do not modify any file outside `$TMP/`.
