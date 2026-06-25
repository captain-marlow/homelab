## Overview

This document outlines a scientifically optimized Proxmox infrastructure build with performance-tested ZFS storage, unprivileged LXC containers running Docker services, and a domain-based external access strategy.

## Hardware & Pool Configuration

### Physical Setup

- **Host**: Proxmox VE server with pfSense handling routing/DDNS
- **Storage**: 4x 2TB NVMe drives in two mirrored pools
- **Domain**: `mydomain.com` with DDNS updating to home IP via pfSense

### ZFS Pool Architecture

```bash
# Flash Pool (Performance Tier)
flash/ - 2x 2TB NVMe in RAID 1 mirror
├── Pool settings: ashift=12, compression=lz4
└── Purpose: High-performance workloads (VMs, app configs, databases)

# Tank Pool (Storage Tier)  
tank/ - 2x 2TB NVMe in RAID 1 mirror
├── Pool settings: ashift=12, compression=lz4
└── Purpose: Bulk storage (media, backups, ISOs)
```

## Storage Optimization (Performance Tested)

### Record Size Testing Results

Conducted real-world fio benchmarking to determine optimal record sizes:

**Small Random I/O (VM/Database workloads):**

- 16K recordsize: ~17-90% faster performance
- Use case: OS operations, databases, application configs

**Large Sequential I/O (Media/Backup workloads):**

- 128K recordsize: 320% faster performance
- Use case: Media streaming, large file operations

### Dataset Structure

#### Flash Pool (16K recordsize - Random I/O optimized)

```bash
flash/
├── vms/           # VM and LXC root filesystems
└── docker/            # Application configurations and databases
    ├── nginx-proxy/   # NPM configs
    ├── jellyfin/      # Jellyfin configs
    ├── radarr/        # Radarr configs
    ├── qbittorrent/   # qBittorrent configs
    └── [other-apps]/  # Additional app configs
```

#### Tank Pool (128K recordsize - Sequential I/O optimized)

```bash
tank/
├── media/             # Media files (SINGLE dataset for hardlinks)
│   ├── movies/        # Final movie location
│   ├── tv/           # Final TV show location  
│   ├── music/        # Music library
│   └── torrents/     # Download handling
│       ├── incomplete/  # Active downloads
│       └── complete/    # Completed downloads (hardlinks to final)
├── backups/          # Backup storage
│   ├── proxmox/      # Proxmox VZDump backups
│   ├── docker/       # Configuration backups
│   └── external/     # Manual/external backups
└── isos/             # ISO images and templates
```

### Proxmox Storage Integration

```bash
# Storage configurations in Proxmox:
vms       (ZFS pool)  - flash/vms     - VM/LXC disks with snapshots
isos      (Directory) - tank/isos          - ISO images and LXC templates  
backups   (Directory) - tank/backups/proxmox - VZDump backups
```

## LXC Architecture Strategy

### Container Philosophy

**Chosen approach**: Docker-in-LXC with service grouping

- **Benefits**: Resource efficiency, service isolation, hardlink preservation
- **Strategy**: Group related services per LXC (e.g., all Servarr apps together)

### UID/GID Mapping Configuration

**Unprivileged LXCs** with custom mapping for secure file access:

#### Host Preparation (one-time setup)

```bash
# Enable custom UID/GID mapping
echo "root:1000:1" >> /etc/subuid
echo "root:1000:1" >> /etc/subgid
```

#### LXC Configuration Template

```bash
# Add to each LXC config (/etc/pve/lxc/[ID].conf):
lxc.idmap: u 0 100000 1000      # UIDs 0-999 → 100000-100999
lxc.idmap: g 0 100000 1000      # GIDs 0-999 → 100000-100999  
lxc.idmap: u 1000 1000 1        # UID 1000 → 1000 (direct mapping)
lxc.idmap: g 1000 1000 1        # GID 1000 → 1000 (direct mapping)
lxc.idmap: u 1001 101001 64535  # UIDs 1001+ → 101001+
lxc.idmap: g 1001 101001 64535  # GIDs 1001+ → 101001+
```

### Standard LXC Mount Strategy

```bash
# Consistent mount points across all LXCs:
mp0: /mnt/flash/docker/[app-name],mp=/config    # Application configs
mp1: /mnt/tank/media,mp=/data                   # Media access (if needed)
```

## Current Infrastructure Status

### Completed Components

#### 1. Storage Infrastructure ✅

- ZFS pools created and optimized
- Datasets configured with performance-tested record sizes
- Proxmox storage integration complete
- File ownership configured (1000:1000 for LXC access)

#### 2. LXC 100: Nginx Proxy Manager ✅

```bash
# Configuration:
Hostname: nginx-proxy
IP: 192.168.1.100
Memory: 2048MB, Cores: 1
Mount: /mnt/flash/docker/nginx-proxy → /config
Features: nesting=1, keyctl=1
Status: Running with SSH access

# Docker Installation: ✅
- Official Docker repository installed
- Docker user created (UID 1000)  
- User added to docker and sudo groups
- Ready for NPM container deployment
```

### In Progress

#### NPM Container Deployment

```yaml
# Planned docker-compose.yml (/config/docker-compose.yml):
version: '3.8'
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443' 
      - '81:81'
    volumes:
      - /config/data:/data                    # NPM app data
      - /config/letsencrypt:/etc/letsencrypt  # SSL certificates
    environment:
      - PUID=1000
      - PGID=1000
```

### Planned LXCs

#### LXC 103: Jellyfin Media Server

```bash
# Configuration:
Hostname: jellyfin
IP: 192.168.1.103  
Memory: 4096MB, Cores: 4
Mounts: 
  - /mnt/flash/docker/jellyfin → /config
  - /mnt/tank/media → /data (read-only)
```

#### LXC 104: Media Management (Servarr Stack)

```bash
# Planned services in one LXC:
- Radarr (movies)
- Sonarr (TV shows)  
- Lidarr (music)
- Prowlarr (indexers)
- qBittorrent (downloads)
- Overseerr (requests)
```

#### LXC 199: Infrastructure Management

```bash
# Planned services:
- Portainer (Docker management across all LXCs)
- Watchtower (automated updates)
- Uptime Kuma (monitoring)
```

## Network & Domain Strategy

### External Access Architecture

```
Internet → mydomain.com (DDNS) → pfSense → NPM (192.168.1.100) → Services
```

### Subdomain Plan

- `jellyfin.mydomain.com` → LXC 103:8096
- `radarr.mydomain.com` → LXC 104:7878
- `portainer.mydomain.com` → LXC 199:9000
- `npm.mydomain.com` → LXC 100:81 (admin)

### pfSense Configuration Required

```bash
# Port forwarding:
WAN:80,443 → NPM LXC (192.168.1.100:80,443)

# DNS Host Overrides for internal access:
jellyfin.mydomain.com → 192.168.1.100
[subdomain].mydomain.com → 192.168.1.100
```

## Docker Volume Mapping Standards

### Application-Specific Mapping

Different container images expect different internal paths:

```yaml
# LinuxServer.io images (Radarr, Sonarr, Lidarr, Jellyfin):
volumes:
  - /config:/config       # Standard for LinuxServer images
  - /data:/data          # Media access

# NPM (official image):
volumes:
  - /config/data:/data                    # NPM expects /data
  - /config/letsencrypt:/etc/letsencrypt  # SSL certificates

# General pattern:
# LXC standardizes on /config mount point
# Docker volumes map to whatever each container expects
```

### Hardlink Preservation Strategy

**Critical**: All Servarr apps must see the same filesystem for hardlinks to work:

```yaml
# ALL media apps use same data mount:
volumes:
  - /config:/config
  - /data:/data              # Single mount point for entire media dataset

# Configure paths within applications:
# Downloads: /data/torrents/complete
# Movies: /data/movies  
# TV: /data/tv
# Music: /data/music
```

## Management Tools Strategy

### Multi-LXC Container Management

**Portainer** chosen for centralized Docker management:

- Can manage Docker containers across multiple LXCs via Docker API
- Web interface for deployment, monitoring, logs
- Template marketplace for easy service deployment

### Update Automation

**Watchtower** for automated container updates:

- Can monitor multiple Docker hosts remotely
- Automatic image updates with configurable schedules
- Maintains container configuration during updates

### Implementation Plan

1. Deploy Portainer in Infrastructure LXC
2. Enable Docker API on all LXCs (port 2376)
3. Add all LXCs as endpoints in Portainer
4. Deploy Watchtower instances for each LXC
5. Centralized monitoring via Uptime Kuma

## Next Steps

1. **Complete NPM Setup**: Deploy NPM container and configure basic reverse proxy
2. **Create Jellyfin LXC**: Test media access and external domain access
3. **Configure External Access**: Set up pfSense port forwarding and DNS overrides
4. **Test SSL Certificate Generation**: Verify Let's Encrypt integration
5. **Deploy Infrastructure LXC**: Set up Portainer for centralized management
6. **Build Media Stack LXC**: Deploy complete Servarr ecosystem
7. **Implement Monitoring**: Add Uptime Kuma and notification systems

## Key Technical Decisions

### Storage Optimization

- **Scientific approach**: Real benchmarking drove recordsize decisions
- **Workload separation**: 16K for random I/O, 128K for sequential I/O
- **Hardlink strategy**: Single dataset approach for media management
- **Backup hierarchy**: Configs (high priority) vs media (lower priority)

### Security Architecture

- **Unprivileged LXCs**: Host protection via namespace isolation
- **Custom UID mapping**: Secure file access without privilege escalation
- **Service isolation**: Major services in separate LXCs
- **SSL everywhere**: Let's Encrypt certificates for all external access

### Scalability Foundation

- **Domain-based access**: Clean subdomain structure for services
- **Modular design**: Easy addition of new services as LXCs
- **Centralized management**: Portainer for unified container control
- **Infrastructure as code**: Docker-compose files for reproducible deployments

This setup provides enterprise-grade storage optimization, security isolation, and management capabilities while maintaining the flexibility to expand with additional services and the performance to handle multiple concurrent users and high-bandwidth media streaming.