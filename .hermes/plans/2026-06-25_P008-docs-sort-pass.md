# P008: Documentation Sort Pass Implementation Plan

> **For Hermes:** This plan is structured for autonomous execution, one task at a time, with a lint gate after each. Commit after each task group.

**Goal:** Bring all repo docs to `STYLE.md` compliance — fix markdownlint structure issues, Vale terminology, em-dash rewrites, and the `docs/ollama/` structural gap. Vale warnings are non-blocking but track progress; markdownlint errors (MD013 excepted) should reach zero.

**Approach:** Four task groups in priority order. Groups 1–3 are mechanical (sed/patch safe); Group 4 (em-dash) requires judgment per instance. Do not touch content meaning — only style surface.

**Scope:** `docs/`, `STATE.md`, `projects.md`, `ideas.md`, `README.md`

---

## Worklist baseline (as of P007 completion)

| Category | Count | Files affected |
|---|---|---|
| MD013 line-length | 379 | Many — deferred (see note) |
| MD022 blanks-around-headings | 48 | ~18 files |
| MD032 blanks-around-lists | 35 | ~15 files |
| MD031 blanks-around-fences | 19 | ~10 files |
| MD007 ul-indent | 9 | ~5 files |
| MD009 trailing spaces | 6 | ~4 files |
| MD047 trailing newline | 5 | ~5 files |
| MD041 first-line-h1 | 5 | ~5 files |
| MD034 bare URLs | 5 | ~4 files |
| MD012 multiple blanks | 5 | ~3 files |
| MD058 blanks-around-tables | 2 | ~2 files |
| Vale Terms (openclaw/proxmox) | 25 | `STATE.md`, `projects.md`, `docs/openclaw/two-agent-loop.md` |
| Vale EmDash | 75 | 19 files |
| Missing `docs/ollama/knowledge-base/` | structural | `docs/ollama/` |

**MD013 note:** Line-length (379 findings) is mostly table rows and long narrative paragraphs. These are deferred — the STYLE.md §5 allows prose wrapping at author discretion and table cells can't be shortened without breaking the table. Fix only clear, short-prose violations where a line wrap is obvious and safe.

---

## Task Group 1 — Terminology fixes (Vale Terms)

**Objective:** Zero `Homelab.Terms` warnings across the full scan scope.

**Files to touch:**
- `STATE.md`
- `projects.md`
- `docs/openclaw/two-agent-loop.md`

**What to fix:** `openclaw` → `OpenClaw`, `proxmox` → `Proxmox` in body prose. Do NOT change occurrences inside code blocks, shell snippets, file paths, or URLs — those are exempt (Vale skips them, and they're correct as-is).

**Step 1: Find all lowercase instances in the three files**

```bash
grep -n "openclaw\|proxmox" STATE.md projects.md docs/openclaw/two-agent-loop.md
```

**Step 2: Apply fixes with sed (case-sensitive, body prose only)**

```bash
# Verify no code-block collateral before running
sed -i '' 's/\bopenclaw\b/OpenClaw/g' STATE.md projects.md docs/openclaw/two-agent-loop.md
sed -i '' 's/\bproxmox\b/Proxmox/g' STATE.md projects.md docs/openclaw/two-agent-loop.md
```

**Step 3: Verify — re-run Vale, expect zero Terms warnings**

```bash
vale --output line STATE.md projects.md docs/openclaw/two-agent-loop.md 2>&1 | grep Terms
```

**Step 4: Commit**

```bash
git add STATE.md projects.md docs/openclaw/two-agent-loop.md
git commit -m "fix(P008): terminology — openclaw→OpenClaw, proxmox→Proxmox"
```

---

## Task Group 2 — Structure fixes (non-MD013 markdownlint)

**Objective:** Eliminate all markdownlint errors except MD013 (line-length, deferred).

Fix these rule violations across all affected files:

| Rule | What to do |
|---|---|
| MD022 | Add a blank line before and after each heading |
| MD032 | Add a blank line before and after each list block |
| MD031 | Add a blank line before and after each fenced code block |
| MD007 | Fix list indentation to 2 spaces per level |
| MD009 | Remove trailing spaces |
| MD047 | Ensure each file ends with a single newline |
| MD041 | Add `# Title` as first line if missing (or check if file should be excluded) |
| MD034 | Wrap bare URLs in `<url>` or `[text](url)` |
| MD012 | Collapse multiple consecutive blank lines to one |
| MD058 | Add blank line before and after tables |

**Priority order (by impact):** Work file by file, heaviest first:
1. `docs/openclaw/openclaw-failover-reference-2026-06-21.md` (27 non-MD013 hits)
2. `docs/proxmox/setup/03 Privileged LXC Pattern.md` (18 hits)
3. `docs/openclaw/step1-completion-record.md` (14 hits)
4. `docs/proxmox/knowledge-base/Common Workflows.md` (13 hits)
5. `docs/proxmox/synapse-matrix.md` (10 hits)
6. Remaining files in order

**Step 1: Run markdownlint for a single file, fix, re-run until clean**

```bash
markdownlint --config .markdownlint.jsonc --ignore-path .markdownlintignore \
  "docs/openclaw/openclaw-failover-reference-2026-06-21.md" 2>&1
```

Fix findings (use `patch` tool for targeted changes — never bulk sed on structure). Re-run. Repeat.

**Step 2: After all files pass (excluding MD013), run full scan to confirm**

```bash
markdownlint --config .markdownlint.jsonc --ignore-path .markdownlintignore \
  docs/ STATE.md projects.md ideas.md README.md 2>&1 | grep -v MD013
```

Expected: zero output (or only MD013 lines).

**Step 3: Commit**

```bash
git add -A
git commit -m "fix(P008): markdownlint structure — MD022/031/032/007/009/047/041/034/012/058"
```

---

## Task Group 3 — `docs/ollama/` structural gap

**Objective:** Create the missing `docs/ollama/knowledge-base/` subfolder that the README references but doesn't exist on disk.

**Step 1: Check what the README expects**

```bash
cat docs/ollama/ollama-tier.md | grep -i "knowledge"
cat README.md | grep -i "ollama"
```

**Step 2: Create the subfolder with a stub README**

Create `docs/ollama/knowledge-base/README.md`:

```markdown
# Ollama Knowledge Base

Reference notes and runbooks for the Ollama LXC tier.

_Nothing here yet — add notes as they accumulate._
```

**Step 3: Verify linters pass on the new file**

```bash
markdownlint --config .markdownlint.jsonc docs/ollama/knowledge-base/README.md && echo CLEAN
vale docs/ollama/knowledge-base/README.md 2>&1
```

**Step 4: Commit**

```bash
git add docs/ollama/knowledge-base/README.md
git commit -m "docs(P008): create docs/ollama/knowledge-base/ stub (structural drift fix)"
```

---

## Task Group 4 — Em-dash rewrites (Vale EmDash)

**Objective:** Reduce Vale `Homelab.EmDash` warnings to zero (or near-zero for any genuinely exempt instances).

**Files with em-dashes (by count):**

| File | Count |
|---|---|
| `STATE.md` | 11 |
| `docs/openclaw/step1-completion-record.md` | 9 |
| `docs/proxmox/synapse-matrix.md` | 8 |
| `docs/hermes/hermes-mac.md` | 8 |
| `docs/openclaw/scope-B-homelab-agent.md` | 5 |
| `docs/openclaw/two-agent-loop.md` | 4 |
| `docs/openclaw/scope-A-openclaw-gateway-backlog.md` | 4 |
| `docs/ollama/ollama-tier.md` | 4 |
| `projects.md` | 3 |
| `docs/openclaw/openclaw-failover-reference-2026-06-21.md` | 3 |
| `docs/openclaw/concepts-reference.md` | 3 |
| `docs/openclaw/architect-agent.md` | 3 |
| `docs/proxmox/setup/02 Storage and ZFS Layout.md` | 2 |
| `docs/openclaw/matrix-bot-channel.md` | 2 |
| `README.md` | 2 |
| Others | 1 each |

**Rewrite rules (from STYLE.md §7):**

- Em-dash as a comma substitute → use a comma or restructure
- Em-dash as a parenthetical → use parentheses `(like this)`
- Em-dash as a sentence-ending elaboration → use a period and a new sentence
- Em-dash in H1 subtitles → exempt, leave as-is

**Process per file:**

```bash
# 1. Get the exact lines
vale --output line <file> 2>&1 | grep EmDash

# 2. Open the file, read context, decide rewrite type
# 3. Apply with patch tool (line-specific, never bulk replace)
# 4. Re-run vale on that file to confirm zero EmDash warnings
vale <file> 2>&1 | grep EmDash
```

**Step — after all files: full scan**

```bash
vale --output line docs/ STATE.md projects.md ideas.md README.md 2>&1 | grep EmDash
```

Expected: zero (or H1-subtitle exceptions — note any remaining ones are intentionally exempt).

**Commit per batch (e.g., by subdirectory or file group)**

```bash
git add <files>
git commit -m "fix(P008): em-dash rewrites — <scope summary>"
```

---

## Final gate

After all four groups, run the full combined lint check:

```bash
cd /Users/ryan/Developer/homelab-hermes

echo "=== markdownlint (non-MD013) ==="
markdownlint --config .markdownlint.jsonc --ignore-path .markdownlintignore \
  docs/ STATE.md projects.md ideas.md README.md 2>&1 | grep -v MD013

echo "=== vale ==="
vale docs/ STATE.md projects.md ideas.md README.md 2>&1
```

Expected:
- markdownlint: zero non-MD013 findings
- vale Terms: zero
- vale EmDash: zero (or noted exemptions only)

Then update `STATE.md` and `projects.md`:
- Move P008 to Completed
- Update "Last updated" to today
- Remove P008 from active queue

Final commit:

```bash
git add STATE.md projects.md
git commit -m "docs(P008): mark complete — docs sort pass done"
```

Push and refresh all three clones:

```bash
git push origin main
cd /Users/ryan/Developer/homelab && git pull --ff-only
# CT175 refresh via OpenClaw or ssh git pull
```

---

## What P008 does NOT touch

- MD013 line-length violations in table rows or long narrative paragraphs (deferred)
- Content meaning — only surface style
- `docs/meta/_voice-samples/` — excluded from linting per `.vale.ini`
- Code blocks, shell snippets, file paths, URLs — Vale skips these, leave as-is
