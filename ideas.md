# Homelab — Ideas

*Loose pool of not-yet-projects. No order, no status discipline. When something firms up into a concrete next step, promote it to `projects.md` and delete it here.*

**Last updated:** 2026-06-23

---

- **Public / friends-and-family Matrix** — someday-goal, not a priority. Would mean flipping federation on (currently off; off-now/on-later is the clean direction).
- **Tailscale** — optional layer on top of the existing WireGuard remote access. Not a dependency for anything current.
- **AMD GPU for Ollama** — deferred due to VRAM limits and ROCm complexity. CPU/RAM tier first.
- **Architect on a local model** — once Ollama is proven, decide whether architect stays on Opus or moves to local. Decide empirically.
- **Second Obsidian vault sync** — personal-notes vault cloud sync method still TBD (separate from the homelab-repo-mirror vault).
- **`STYLE.md` for architect** — response-style spec (shorter, fewer caveats). Nice-to-have, floats free, applies once architect exists.
- **Stricter agent gate** — if `allowBots: "mentions"` flow feels too loose in practice, consider an explicit-command gate instead. Decide during the two-agent loop build.
- **OpenClaw "prose"** — explore further: https://docs.openclaw.ai/prose
- **Ansible auto-registers new LXCs in Mac `~/.ssh/config`** — every LXC created via the Mac Ansible flow should append a `Host` block (alias / `HostName` / `User` / `IdentitiesOnly yes` / `IdentityFile`) matching the existing uniform pattern, so new containers are reachable by name immediately. A `blockinfile` task keyed on the alias. Belongs with the Ansible/Hermes repo-integration work (P006).
- **Ansible LXC baseline-hardening role** — every new LXC should come up hardened by default: push the Mac's public key into the container (`authorized_keys` for the admin user) for immediate key-based access; **disable root SSH login** (`PermitRootLogin no`) and password auth (key-only); create a non-root sudo user; plus a general pass (firewall, unattended security upgrades). A reusable `baseline`/`hardening` role applied to every container. Pairs with the SSH-config auto-add above; same Ansible/Hermes track (P006).
