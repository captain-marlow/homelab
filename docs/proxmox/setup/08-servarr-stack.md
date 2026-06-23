# 08 — Servarr Stack (CT150)

This document covers the deployment of the media automation engine. Located in the Servarr LXC (`ct150`), this stack handles the discovery, acquisition, and organization of media. It is strictly routed through the VPN to ensure privacy and operates on a specific storage architecture to enable instant file management.

---

## I. Container Identity and Networking

The Servarr LXC is the primary consumer of the VPN failover group established in **[(01) pfSense Base and VPN Failover](./01-pfsense-base-and-vpn.md)**.

- **LXC Management IP:** 192.168.1.150
- **Gateway:** 192.168.1.1 (pfSense)
- **VPN Policy:** This IP is a member of the `VPN_Clients` alias. If the Mullvad tunnels go down, the pfSense Kill-Switch will immediately drop all traffic for this container.
- **DNS:** Queries are routed to pfSense for encrypted **[pfSense DNS and Security](../knowledge-base/pfsense/dns-and-security.md)**, ensuring trackers cannot see metadata lookups.

---

## II. Storage Strategy (The Hardlink Secret)

To ensure that moving a completed download into your media library is instantaneous and consumes zero extra disk space, we follow the "Atomic Move" pattern.

- **Config Mount:** `/mnt/flash/docker/servarr` -> `/config`
  - *Rationale:* Optimized with a 16K recordsize to handle high-frequency SQLite database writes from Sonarr and Radarr.
- **Media Mount:** `/mnt/media` -> `/media`
  - *Rationale:* Optimized with a 128K recordsize for sequential video streaming and large file transfers.
- **Critical Requirement:** All subfolders (torrents, usenet, movies, tv) **must** reside within the same `/media` mount. If you split "Downloads" and "Media" into two different mount points, ZFS cannot perform a hardlink, forcing a slow and intensive "copy+delete" operation.

---

## III. The Core Servarr Services

We deploy these services as a unified stack via Docker Compose.

- **Prowlarr:** The indexer manager. It syncs trackers to Sonarr and Radarr.
- **Sonarr/Radarr:** The "brains" that monitor for new TV shows and movies.
- **qBittorrent/Sabnzbd:** The download clients.
- **Jellyfin:** The open-source media server that provides the front-end UI.
  - *Note:* Jellyfin can be moved to a separate LXC later if Hardware Acceleration (Transcoding) requires dedicated GPU passthrough.

---

## IV. Docker Compose Configuration

The stack is defined in `/config/docker-compose.yml`. We enforce the UID/GID 1000 standard to match the ZFS host permissions.

```yaml
services:
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /config/prowlarr:/config
    ports:
      - 9696:9696
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /config/sonarr:/config
      - /media:/media
    ports:
      - 8989:8989
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /config/radarr:/config
      - /media:/media
    ports:
      - 7878:7878
    restart: unless-stopped

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - WEBUI_PORT=8080
    volumes:
      - /config/qbittorrent:/config
      - /media/torrents:/media/torrents
    ports:
      - 8080:8080
      - 6881:6881
      - 6881:6881/udp
    restart: unless-stopped
```

---

## V. Permission and Hardlink Verification

Once the stack is up, you must verify that the user (UID 1000) can perform the necessary file operations.

- **Test Write Access:**
  - `docker exec -it sonarr touch /media/test.txt`
- **Verify Hardlinks:**
  - After a successful download, check the inode of the file in both the download folder and the media library.
  - `ls -i /media/torrents/complete/movie.mkv`
  - `ls -i /media/movies/movie.mkv`
  - *Result:* If the inode numbers match, the hardlink is successful. This preserves SSD health and provides instant "moves."

---

**Knowledge Base References:**

- **[pfSense Networking and Routing](../knowledge-base/pfsense/networking-and-routing.md)**
- **[Proxmox Infrastructure Setup](../knowledge-base/proxmox/infrastructure-setup.md)**
- **[Privileged vs Unprivileged LXCs](../knowledge-base/proxmox/privileged-vs-unprivileged-lxcs.md)**

Proceed to the next file:
-> **[(09) Post-Install and Backup Strategy](./09-post-install-and-backup-strategy.md)**
