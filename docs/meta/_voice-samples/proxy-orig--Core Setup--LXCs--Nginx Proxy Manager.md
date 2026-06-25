Use the [Privileged Docker LXC Pattern](obsidian://open?vault=Obsidian%20Vault&file=Documentation%2FOperating%20Systems%2FProxmox%2FCore%20Setup%2FLXCs%2FPrivileged%20Docker%20LXC%20Pattern%20(Proxmox%20VE%209)) to setup.

## pfSense Port Forwards
We'll want to forward all HTTP and HTTPs traffic to NPM. Create to NAT port forward rules:

**Rule 1 - HTTP
- Interface: WAN
- Protocol: TCP
- Destination: WAN address
- Destination port: HTTP
- Redirect target IP: `192.168.1.100` (NPM LXC)
- Redirect target port: 80
- Description: Forward HTTP traffic on WAN to NPM

**Rule 2 - HTTPS**
- Interface: WAN
- Protocol: TCP
- Destination: WAN address
- Destination port: HTTPS
- Redirect target IP: `192.168.1.100`
- Redirect target port: 443
- Description: Forward HTTPS traffic on WAN to NPM