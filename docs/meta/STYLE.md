# Documentation Style Guide — house conventions for the homelab repo (P007)

**Status: draft (P007 Steps 1 + voice complete, 2026-06-25). Linters pending (Steps 2-3).**

This guide codifies the style already in use across the repo. It is descriptive of what
exists, not prescriptive of a new style. When in doubt, follow the nearest existing doc
and consult this guide for the edge case.

---

## 1. Terminology

Canonical spellings. Use these forms in all prose and headers. The "avoid" column lists
forms seen in the wild that are wrong.

| Term | Canonical | Avoid |
|------|-----------|-------|
| OpenClaw | `OpenClaw` | `openclaw`, `open-claw`, `OpenCLaw` |
| Synapse | `Synapse` | `synapse` (in prose; lowercase in shell) |
| Proxmox | `Proxmox` | `proxmox`, `ProxMox` |
| pfSense | `pfSense` | `Pfsense`, `pfsense`, `PFsense` |
| Matrix | `Matrix` | `matrix` (when referring to the protocol/network) |
| Ollama | `Ollama` | `ollama` (in prose; lowercase in shell commands) |
| Hermes | `Hermes` | `hermes` (in prose) |
| LXC | `LXC` | `lxc`, `container N` (use `` `CT###` `` instead) |
| Container IDs | `` `CT###` `` | "container 175", "container N", `CT 175` |
| E2EE | `E2EE` | `e2ee`, `end-to-end encrypted` (spell out only on first mention) |
| SecretRef | `SecretRef` | `secretref`, `secret ref`, `secret-ref` |
| MXID | `MXID` | `mxid`, `Matrix ID` |
| WireGuard | `WireGuard` | `wireguard`, `Wireguard` |
| ZFS | `ZFS` | `zfs` (in prose) |
| Agent handles | `` `@openclaw` ``, `` `@architect` ``, `` `@hermes` `` | bare `@openclaw` without backticks in prose |

> Container IDs are always backticked and zero-padded to three digits: `` `CT175` ``, not
> `CT 175` or "container 175".

---

## 2. Header conventions

- Use ATX style (`#`), not setext (`===` / `---` underlines).
- H1 format: **Title Case**, em-dash (—) separator, subtitle, project-ID tag in
  parentheses at the end:

  ```
  # Architect Agent — read-only Opus planner (P003)
  ```

- H2 and below: sentence case or short noun phrase; no project-ID tag.
- Emoji are allowed in identity files (e.g. `SOUL.md`, agent `MEMORY.md`) but are **not
  required** in documentation files.
- Do **not** add trailing punctuation to headers.

---

## 3. Status-line convention

Every documentation file opens with a bold-lead status line immediately after the H1
(before any prose or `---` divider):

```
**Status: live (P005 complete, 2026-06-24).**
```

Variants in use:

| Variant | Example |
|---------|---------|
| Live / complete | `**Status: live (P006 complete, 2026-06-25).**` |
| In-progress | `**Status: in progress (P007, step 1 of 3).**` |
| Deferred | `**Status: deferred — waiting on D001.**` |
| Draft / partial | `**Status: draft (P007 Step 1 complete, 2026-06-25). Section 7 pending.**` |

The status line is kept current. It is the first thing a reader sees after the title.

---

## 4. Lists, tables, and callouts

**Lists:** use dash (`-`) bullets. Avoid `*` and `+`. Nested lists indent two spaces.

**Ordered lists:** use `1.`, `2.`, `3.` — not `a.`, `i.`, or manual re-numbering after
edits (Markdown renderers renumber automatically).

**Tables:** pipe tables are used freely for reference material, key–value pairs, and
comparison grids. Always include the header separator row. Align pipes visually for short
tables; auto-format is acceptable for long tables.

**Callouts / gotchas:** use `>` blockquotes for warnings, cautions, and hard-won
operational notes. A single sentence is fine; no special label prefix required (the
indentation signals "pay attention").

> Example: this is how a gotcha looks. Put anything the reader must not skip here.

**Code:** inline backticks for commands, file paths, config keys, agent handles, and
container IDs. Fenced code blocks (triple backtick) for multi-line snippets; include a
language tag when the syntax is non-obvious (`json`, `yaml`, `bash`, `json5`).

---

## 5. Prose width

Hard-wrap prose at **94 columns**. This applies to paragraph text and list items.
Exceptions — do **not** wrap:

- Fenced code blocks (wrap inside only if the code itself warrants it).
- Table rows (a long cell is preferable to a broken pipe table).
- URLs on their own line.

The 94-column limit matches the repo's target line length. Use an editor ruler or
`fmt -w 94` to enforce.

---

## 6. Architect response-style spec

The `architect` agent (`@architect`) is the planner in the two-agent loop. Its response
style differs from a general assistant:

- **Shorter.** Prefer one crisp sentence over a qualified paragraph.
- **Fewer hedges and caveats.** State the finding, not all the ways it could be wrong.
  Reserve caveats for genuine load-bearing uncertainty.
- **Opinionated on sequencing.** When steps have dependencies, name the order and say
  why. Do not present N equally valid orderings and leave the choice to the reader.
- **No preamble.** Start with the answer or the next action, not a restatement of the
  question.
- **No sign-off filler.** Skip "Let me know if you have questions" and similar.

These norms apply to the architect's Matrix responses, its planning docs, and any
step-completion records it writes.

---

## 7. Voice and verbosity norms

Voice is anchored on Ryan's hand-written originals (`docs/meta/_voice-samples/proxy-orig--*`),
not on later collaboratively-edited docs. Keep the *texture* below; drop the working-notes
mess (stray TODOs, raw link-dumps, typos).

**One voice, two registers.** The voice is constant; verbosity and where-the-"why"-lives
differ by doc type (per the `setup/` vs `knowledge-base/` split in `README.md`):

- **`setup/`** — a short, to-the-point tutorial a human can follow along to replicate the
  build in their own homelab. When a technical decision is made, state the reasoning in
  **one plain sentence plus a link to `knowledge-base/`** for the depth — don't inline the
  full rationale.
- **`knowledge-base/`** — the technical depth and design decisions (e.g. privileged vs
  unprivileged LXCs, UID/GID mapping, auth rationale) plus reference links. This is where
  the reason-aloud teaching runs long.

Texture (applies to both registers):

- **Teach by reasoning, not just instructing.** Define a thing, then immediately say *why*
  it works that way and give a concrete example. Don't state a step without its rationale
  when the rationale is non-obvious.
- **Concrete example right after the abstract claim.** Every general rule earns a specific
  instance — a command, a path, a number. Prefer `chown -R 1000:1000 /mnt/media` over
  "set appropriate ownership."
- **First-person plural, walking the reader through.** "We'll use Turnkey Core," "in our
  case," "let's create a dataset." A guide you're walking beside someone on, not a spec
  sheet.
- **Bold the procedural pivots.** **First**, **Second**, **Don't**, **Note:** — bold the
  words that carry the procedure's turning points and warnings.
- **State the deliberate choice and why.** When a decision was made for a reason ("Using
  SATA for the OS is deliberate. It preserves the NVMe slots..."), say so plainly. Name the
  rejected alternative when it clarifies.
- **Be honest about uncertainty — but resolve it before it ships.** Don't fake false
  confidence; don't leave a literal "or whatever" either. If something is genuinely open,
  mark it explicitly with a `>` callout rather than burying live debate in prose.
- **Verbosity: as long as the reasoning needs, no longer.** Short where a step is obvious;
  expanded where a choice has consequences.
- **No marketing voice.** Plain, direct, slightly informal. "This is the most basic option"
  — not "leverage this powerful feature."

> The architect's own response style (§6) is the terser subset of this — same reason-first,
> honest instinct, fewer words, for chat/planning rather than tutorials.
