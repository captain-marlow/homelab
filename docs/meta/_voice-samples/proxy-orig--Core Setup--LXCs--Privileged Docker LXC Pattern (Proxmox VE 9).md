## Purpose

This pattern defines a **repeatable, low-friction way to run Docker workloads inside Proxmox VE** using **privileged LXCs**, optimized for:
- Docker compatibility (no AppArmor or sysctl hacks)
- Scriptable, non-interactive setup
- Predictable filesystem ownership
- Clean separation between infrastructure layers (Proxmox → LXC → Docker)
- Reverse-proxy–based service exposure via Nginx Proxy Manager (NPM)

This pattern is intended for **infrastructure-adjacent services** (reverse proxy, automation stacks, internal services), not hostile multi-tenant environments.

---
## Design Rationale

### Why a _privileged_ LXC?

Running Docker inside an **unprivileged LXC** frequently encounters friction due to:
- kernel capability restrictions
- AppArmor profile conflicts
- sysctl access limitations (e.g., `ip_unprivileged_port_start`)
- container runtime assumptions that break under user-namespace remapping

On **Proxmox VE 9**, a **privileged LXC with `nesting=1,keyctl=1`**:
- matches Docker’s expectations
- avoids compatibility workarounds
- behaves like a “lightweight VM” without VM overhead
    
**Trade-off:**  
You give up user-namespace isolation in exchange for operational simplicity and reliability. This is acceptable when:
- the container is not directly exposed to the WAN
- ingress is tightly controlled (firewall + reverse proxy)
- datasets and privileges are narrowly scoped

## Pattern Overview

**Host:** Proxmox VE 9  
**Container type:** Privileged LXC  
**Guest OS:** Debian 13 (minimal)  
**Container role:** Docker host  
**Ingress:** Nginx Proxy Manager (Docker)  
**Firewall:** pfSense  
**Persistence:** ZFS bind mounts  
**Identity model:** UID/GID 1000 application user

Throughout the pattern, you may add your own alternations to match your setup. 
## Host-side Storage Preparation (ZFS)
**Setup ZFS dataset**
` zfs create flash/docker/infrastructure/nginx-proxy -o recordsize=16K -o mountpoint=/mnt/flash/docker/infrastructure/nginx-proxy`
**Set permissions**
```bash
# Not used anymore
# chown -R 1000:1000 /mnt/flash/docker/infrastructure/nginx-proxy

# Servarr app state
chown -R 1000:1000 /mnt/flash/docker/servarr
chmod -R 2775 /mnt/flash/docker/servarr

# Media (music/movies/tv/downloads)
chown -R 1000:1000 /mnt/tank/media
chmod -R 2775 /mnt/tank/media
```


**Create LXC with proper UID/GID mapping**

Create the LXC with the options you like:
```bash
pct create 100 isos:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname nginx-proxy \
  --memory 2048 \
  --cores 1 \
  --features nesting=1,keyctl=1 \
  --rootfs vms:8 \
  --mp0 /mnt/flash/docker/infrastructure/nginx-proxy,mp=/config \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1 \
  --ssh-public-keys /root/.ssh/authorized_keys \
  --onboot 1 \
  --unprivileged 0
```

### Setup LXC
Enter your LXC using either `pct` or SSH. 
```
pct start 100
pct enter 100
# Or just SSH into LXC 
ssh root@192.168.1.1
```

### Setup Docker
```bash
# Create doocker user group with GID 1000 (created by Docker during install)
addgroup --gid 1000 docker
# Create docker user with UID 1000, add to docker group, and create home dir
useradd docker -u 1000 -g docker -m -s /bin/bash
# Add to sudo and docker groups
usermod -aG sudo docker

# Update and install prerequisites
apt update && apt upgrade -y
apt install ca-certificates curl -y

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings 
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

# Update package list
apt update

# Install Docker
apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Enable and start Docker
systemctl enable --now docker
# Verify
systemctl status docker --no-pager

# Switch to docker user 
su - docker
# Check if bind mount working
cd /config

# Check if bind mount working
touch /config/_bind_mount_test && ls -l /config/_bind_mount_test
rm /config/_bind_mount_test

# Create app directory
mkdir -p /config/npm
```

From here, there are two paths: either install the Portainer agent and have Portainer manage the Docker engine in the newly created LXC, or manually deploy using Docker Compose. 

### Deploy Portainer Agent (option 1)
In this option, will we install Portainer Agent to allow a Portainer instance to control the Docker engine running on this LXC. This will allow centralized management of all Docker instances in our node. 
```bash
# Create container directory in /config
mkdir -p /config/portainer-agent

# Create Docker Compose YAML file and add options
cat > /config/portainer-agent/docker-compose.yml <<'YAML'
services:
  agent:
    image: portainer/agent:latest
    container_name: portainer_agent
    restart: unless-stopped
    ports:
      - "9001:9001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
YAML

# Deploy Portainer via Docker Compose
cd /config/portainer-agent
docker compose up -d
docker ps
```

Log into Portainer at `192.168.1.200:9000`. 

**Register existing Docker LXC with Agent:**
**Steps:**
- **Environments** → **Add environment**
- Choose **Docker Standalone**
- Choose **Agent**
- Name: `nginx-proxy`

**Deploy Container via Portainer:**
**Home** → **Environments** → **Select Newly Added Environment**. 
- Add Docker Compose text
- Click **Deploy stack**

Portainer server connects to agents on `tcp/9001`.

### Deploy via Docker Compose (option 2)
```bash
cd /config/npm
nano docker-compose.yml
```

`docker-compose.yml`:
```yml
services:
  npm:
    image: jc21/nginx-proxy-manager:2.11.3
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "81:81"
    volumes:
      - /config/data:/data
      - /config/letsencrypt:/etc/letsencrypt
    environment:
      - TZ=America/Los_Angeles
```
### Bring Container Online
```bash
docker compose up -d
docker ps
```

### Finish Setup
You should see both the running Docker container. You can visit the web UI by going to `192.168.1.100:81`. 