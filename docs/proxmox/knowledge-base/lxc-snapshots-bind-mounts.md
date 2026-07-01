# LXC Snapshots and Bind Mounts

## The Problem

`pct snapshot` refuses with "snapshot feature is not available" on any CT that has bind mounts (host-filesystem paths mapped into the container via `mp0`, `mp1`, etc.). This is a Proxmox hard constraint: bind-mounted paths live outside the CT's managed disk volume and can't be captured atomically.

**This applies cluster-wide.** Every standard Docker-host CT in this cluster uses the `host:/path,mp=/config` + `host:/path,mp=/data` bind pattern. None of them are `pct snapshot`-able, regardless of storage backend. ZFS rootfs (flash/vms) would snapshot fine on its own — the bind mounts are the sole blocker.

Affected CTs (as of 2026-06-30): CT100, CT150 (servarr), CT171 (synapse), and any future Docker-host CTs following the same pattern.

CT175 (openclaw) has no bind mounts and is snapshottable normally.

## The Right Backup Strategy

Don't design around `pct snapshot` for these containers. The actual app state lives in the bind-mounted datasets, not the container image. Use:

1. **vzdump** for the rootfs (container image, config, installed packages) — **verified 2026-07-01 (omega, CT150):** `vzdump --mode snapshot` silently downgrades to `--mode stop` on bind-mount CTs; the CT is briefly stopped, rootfs is backed up, bind-mount paths are excluded with "not a volume" warnings. Exit 0 — the job "succeeds" but bind-mounted data is NOT in the archive. Consequence: `vzdump` alone leaves your app data (configs, media) unprotected.
2. **ZFS dataset snapshots on the host** for the bind-mounted data sources (`flash/docker/*`, `tank/media`, etc.) — this captures what matters

```bash
# Example: rootfs revert point
zfs snapshot flash/vms/subvol-150-disk-0@before-upgrade

# Example: app data (recursive captures child datasets)
zfs snapshot -r flash/docker/servarr@2026-06-30

# List snapshots on a dataset
zfs list -t snapshot flash/docker/servarr
```

## Cross-References

- `docs/proxmox/synapse-matrix.md` line 130 — first documented instance of this behavior (CT171/synapse)
- This pattern was confirmed live during Phase 3 Step 4 (omega infra gate, 2026-06-30): `pct snapshot 150 omega-step4-test` failed on CT150 for this exact reason
