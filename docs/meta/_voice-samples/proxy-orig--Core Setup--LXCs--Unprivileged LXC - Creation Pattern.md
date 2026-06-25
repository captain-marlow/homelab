In this tutorial, we'll cover the generic process of building a unprivileged LXC with Docker. In this example, we'll be setting up Nginx Reserve Proxy.

### Data
**Setup ZFS dataset**
` zfs create flash/docker/infrastructure/nginx-proxy -o recordsize=16K -o mountpoint=/mnt/flash/docker/infrastructure/nginx-proxy`
**Set permissions**
`chown -R 1000:1000 /mnt/flash/docker/infrastructure/nginx-proxy

**Create LXC with proper UID/GID mapping**
Create the LXC with the options you like:
```bash
pct create 100 isos:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst --hostname nginx-proxy --memory 2048 --cores 1 --features nesting=1,keyctl=1 --rootfs vms:8 --mp0 /mnt/flash/docker/infrastructure/nginx-proxy,mp=/config --net0 name=eth0,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1 --ssh-public-keys /root/.ssh/authorized_keys --onboot 1 --unprivileged 1
```

Set password for LXC if need be:
`pct set 100 --password your-secure-password`

Before starting, edit LXC conf file to add proper UID/GID mapping:
```bash
nano /etc/pve/lxc/100.conf

# Add to lxc.conf
# UID/GID mapping
lxc.idmap: u 0 100000 1000
lxc.idmap: g 0 100000 1000
lxc.idmap: u 1000 1000 1
lxc.idmap: g 1000 1000 1
lxc.idmap: u 1001 101001 64535
lxc.idmap: g 1001 101001 64535

# Or just SSH into LXC
pct start 100
pct enter 100
```

Now that you're in the LXC, update the system, install Docker, and make Docker user have root privileges:
```bash
# Update and install prerequisites
apt update && apt upgrade -y 
apt install ca-certificates curl gnupg lsb-release -y

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings 
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list
apt update

# Install Docker
apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Create docker user with UID 1000 and add to docker group (created by Docker during install)
useradd docker -u 1000 -g docker -m -s /bin/bash
# Add to sudo and docker groups
usermod -aG sudo docker

# Enable and start Docker
systemctl enable docker 
systemctl start docker

# Switch to docker user 
su - docker
# Check if bind mount working
cd /data

# Check if bind mount working
touch /config/_bind_mount_test && ls -l /config/_bind_mount_test
rm /config/_bind_mount_test

# Deploy NPM via Docker Compose
mkdir -p /config/npm
cd /config/npm
nano docker-compose.yml
```

Write this is the `docker-compose.yml` file:
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

### Fixing LXC AppArmor Issues
If you run this, you will get an error. It has to do with AppArmor, a MAC that controls kernel access policy. This is a chronic issue and why many suggest using a VM for Docker instead. 
https://blog.ktz.me/apparmors-awkward-aftermath-atop-proxmox-9/
https://github.com/opencontainers/runc/issues/4968#issuecomment-3500775431

AppArmor is an addition that the Proxmox developers added for enterprise users. It adds an additional layer of kernel protection. But Docker increasingly relies on access to kernel space to function. AppArmor blocks Docker, leading to errors.

There are multiple steps you can take:

**Block communcation between AppArmor and Docker**
```bash
sudo mount --bind /dev/null /sys/module/apparmor/parameters/enabled
sudo systemctl restart docker
```

OR

**Rollback Containerd Version**
```bash
sudo apt install containerd.io=1.7.28-1~debian.12~noble
sudo apt-mark hold containerd.io
```
A recent update to Containerd (Nov 2025) patched a kernel vulnerability that now impacts LXCs. Reverting the version and holding its version is a temporary solve. Note, however, that in this case, the downgrade is more vulnerable than the new version.

**Disable AppArmor in LXC conf**
```
lxc.apparmor.profile: unconfined
lxc.mount.entry: /dev/null sys/module/apparmor/parameters/enabled none bind 0 0
# don't need this
# lxc.mount.auto: proc:rw sys:rw
```
Future kernel changes may break this again.