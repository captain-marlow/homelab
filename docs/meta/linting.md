# Documentation Linting — markdownlint + Vale (P007)

**Status: live (P007 complete, 2026-06-25).**

## 1. What this is

Two mechanical linters enforce the house style in `STYLE.md`. markdownlint checks Markdown
structure (headers, lists, line length, blank lines). Vale checks prose (canonical
terminology, em-dashes in body text). Both run at `warning` level; they nudge, they do not
block. The style guide is the contract; these are the floor under it.

---

## 2. Where the configs live

- `.markdownlint.jsonc` (repo root), markdownlint rules, tuned to pass existing
  house-style docs.
- `.markdownlintignore` (repo root), excludes untracked trees and
  `docs/meta/_voice-samples/`.
- `.vale.ini` (repo root), Vale core config; styles in `styles/Homelab/`; accept-list in
  `styles/config/vocabularies/Homelab/accept.txt`.

---

## 3. How to run

markdownlint:

```bash
markdownlint --config .markdownlint.jsonc --ignore-path .markdownlintignore \
  "docs/**/*.md" "*.md"
```

Vale:

```bash
vale docs/ STATE.md projects.md ideas.md README.md
```

Install if missing:

```bash
npm install -g markdownlint-cli   # markdownlint
brew install vale                 # Vale
```

---

## 4. How it fits the loop

In the docs sort pass (P008), the architect proposes styled rewrites (read-only), Ryan
gates, and Hermes applies and runs both linters before pushing. The linters are the
mechanical gate; the architect and `STYLE.md` are the judgment gate.

---

## 5. Tuning notes (why some rules are off)

- **MD036 off:** bold-lead status lines are a convention, not headings.
- **MD040 off:** code language tags are situational per §4.
- **MD033 off:** house docs use HTML comments.
- **MD060 off:** table pipe-spacing deferred (see `ideas.md`).
- **Vale EmDash:** uses `scope: sentence` so it catches body prose. Note that `~heading`
  negation is not supported at runtime in Vale 3.15; H1 subtitle em-dashes (per §2) are
  a known accepted finding in pre-existing docs.
