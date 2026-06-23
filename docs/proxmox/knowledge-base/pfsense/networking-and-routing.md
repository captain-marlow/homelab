# Proxmox Networking and Firewall

This manual explains the virtual networking architecture of Proxmox VE and the hierarchical firewall system. It provides the technical foundation for the network configurations detailed in **[setup/03-pve-host-baseline.md](../../setup/03-pve-host-baseline.md)** and ensures you can secure your host without locking yourself out of the management interface.

---

## I. Linux Bridge Architecture (vmbr0)

Proxmox uses a "Linux Bridge" model by default. Think of `vmbr0` as a virtualized physical switch that lives inside your host.

- **The Bridge (`vmbr0`)**: This is the primary virtual switch. It is "bridged" to a physical network interface (e.g., `eno1` or `eth0`).
- **Host IP**: The Management IP (`192.168.1.19`) is assigned to the bridge itself, not the physical port. This allows the host to communicate on the same network as its guests.
- **Guest Access**: When an LXC or VM is created, a virtual cable (tap/veth) is plugged into `vmbr0`. The guest then communicates with the pfSense gateway as if it were a physical machine on your desk.

---

## II. The Proxmox Firewall (PVEFW) Hierarchy

The Proxmox firewall is highly granular and operates at three distinct levels. A rule must be permitted at every level to pass.

1. **Datacenter Level**: Global rules that apply to the entire cluster. This is where you define "Aliases" (like `Admin_Workstation`) and "Security Groups."
2. **Node Level (`pve01`)**: Rules specific to the physical host. This controls access to the Proxmox Web UI (8006) and SSH (22).
3. **Guest Level (VM/LXC)**: Individual firewalls for each container. This is where you would block a specific container from talking to the rest of your LAN.

---

## III. The "Anti-Lockout" Management Rules

Enabling the Proxmox firewall without proper rules is the #1 cause of host "disappearance." Before enabling the firewall at the Datacenter or Node level, you **must** define management access.

### Recommended "Management" Security Group

- **Rule 1**: `IN ACCEPT` | Protocol: `TCP` | Port: `8006` | Source: `Admin_IP` (Web GUI)
- **Rule 2**: `IN ACCEPT` | Protocol: `TCP` | Port: `22`   | Source: `Admin_IP` (SSH)
- **Rule 3**: `IN ACCEPT` | Protocol: `ICMP`|            | Source: `Admin_IP` (Ping)

*Rationale: By restricting management ports to a specific Admin IP or Subnet, you prevent lateral movement if a device on your network is compromised.*

---

## IV. Internal Networking: LXC to LXC

In this lab, services often need to talk to each other (e.g., Sonarr in CT150 needs to talk to Prowlarr in CT100).

- **Path**: Since both LXCs are on the same bridge (`vmbr0`), traffic between them never leaves the Proxmox host. It is switched at memory-speed within the bridge.
- **Firewall Consideration**: If the guest-level firewall is enabled on CT100, you must explicitly allow incoming traffic from CT150 on the required ports (e.g., Port 9696 for Prowlarr).
- **DNS Resolution**: Containers should use the pfSense IP (`192.168.1.1`) for all lookups. pfSense will then resolve internal hostnames or route the request out through the encrypted VPN as defined in **[pfSense DNS and Security](../pfsense/dns-and-security.md)**.

---

## V. Troubleshooting the Network

If a container loses connectivity:

1. **Check the Bridge**: Ensure `vmbr0` is "Active" in the Proxmox Network tab.
2. **Firewall Log**: Check `/var/log/pve-firewall.log` on the host to see if packets are being dropped by a specific rule.
3. **IP Conflict**: Verify that the LXC IP matches the static reservation in **[setup/01-pfsense-base-and-vpn.md](../../setup/01-pfsense-base-and-vpn.md)**.

---

**Related Documentation:**

- **[(03) Proxmox Host Baseline](../../setup/03-pve-host-baseline.md)**
- **[pfSense Networking and Routing](../pfsense/networking-and-routing.md)**
- **[Privileged vs Unprivileged LXCs](./privileged-vs-unprivileged-lxcs.md)**
