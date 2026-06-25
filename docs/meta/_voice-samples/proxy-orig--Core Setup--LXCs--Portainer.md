Use the [Privileged Docker LXC Pattern](obsidian://open?vault=Obsidian%20Vault&file=Documentation%2FOperating%20Systems%2FProxmox%2FCore%20Setup%2FLXCs%2FPrivileged%20Docker%20LXC%20Pattern%20(Proxmox%20VE%209)) to setup.

**Command to create:**
```bash
pct create 200 isos:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname portainer \
  --memory 2048 \
  --cores 1 \
  --features nesting=1,keyctl=1 \
  --rootfs vms:8 \
  --mp0 /mnt/flash/portainer,mp=/config \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.200/24,gw=192.168.1.1 \
  --ssh-public-keys /root/.ssh/authorized_keys \
  --onboot 1 \
  --unprivileged 0
```

**Deploying Portainer via Docker Compose:**
```bash
mkdir -p /config/portainer/data

cat > /config/portainer/docker-compose.yml <<'YAML'
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "8000:8000"
    volumes:
      - /config/data:/data
      - /var/run/docker.sock:/var/run/docker.sock
YAML

cd /config/portainer
docker compose up -d
docker ps
```

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