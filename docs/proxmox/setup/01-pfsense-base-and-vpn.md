# 01 — pfSense Base and VPN Failover

This document establishes the network backbone. Before the Proxmox host is provisioned, the network must be capable of routing traffic securely through a VPN with a "hard fail-closed" policy to prevent data or DNS leaks.

---

## I. Network Baseline

- **LAN Gateway:** 192.168.1.1 (The primary network gateway and local DNS provider).
- **Static Reservations:**
  - 192.168.1.19 — Proxmox Host (pve01). [[PVE01 Hardware](../PVE01/PVE01 Hardware.md)]
  - 192.168.1.100 — Infrastructure LXC (ct100).
  - 192.168.1.150 — Servarr LXC (ct150).
- **Technical Reference:** For a deep dive into the subnet logic and why these specific IPs were chosen, see **[pfSense Networking and Routing](../knowledge-base/pfsense/networking-and-routing.md)**.

---

## II. WireGuard Tunnels (Mullvad)

We use two tunnels for redundancy. This "Dual-WAN" approach ensures that if one Mullvad server experiences maintenance, high latency, or a routing hang, your media stack stays online by failing over to the second tunnel. Repeat these steps for `tun_wg_0` and `tun_wg_1`.

### Phase A: Create the Tunnel

- Go to **VPN -> WireGuard -> Tunnels**.
- **Description:** `Mullvad WireGuard Tunnel 0`.
- **Interface Keys:** Click **Generate**. Copy the **Public Key** to your clipboard.
- Save the Tunnel, but **do not apply changes yet**.
  - *Rationale:* We cannot finalize the connection until we have registered our keys with Mullvad to obtain a valid internal interface IP. Applying the config before registration will cause WireGuard to attempt handshakes with invalid parameters.

### Phase B: Register with Mullvad (Disable DNS Hijacking)

By default, Mullvad hijacks all DNS traffic on port 53. To allow our custom Quad9 DNS to function, we must use Mullvad's API to register our device with DNS hijacking disabled.

Run these commands from your terminal and enter your **Mullvad account number** and the **public key** of the WireGuard tunnel just created:

1. **Get Access Token:**
    - `access_token=$(curl -X POST https://api.mullvad.net/auth/v1/token -H 'Content-Type: application/json' -d '{"account_number":"YOUR_ACCOUNT_NUMBER"}' | jq -r .access_token)`
2. **Register Key without Hijacking:**
    - `curl -X POST https://api.mullvad.net/accounts/v1/devices -H "Authorization: Bearer $access_token" -H 'Content-Type: application/json' -d '{"pubkey":"YOUR_PUBLIC_KEY", "hijack_dns":false}'`

- **Result:** Mullvad will return your assigned internal IPv4 address (e.g., `10.64.x.x`). Note this for Phase C.

### Phase C: Assign the Interface

- Go to **Interfaces -> Assignments** and assign `tun_wg_0` to a new interface.
- **Description:** `MULLVAD_VPN_0`.
- **Enable:** Checked.
- **IPv4 Configuration Type:** Static IPv4.
- **MTU:** 1420 | **MSS:** 1380.
  - *Rationale:* WireGuard adds a 60-byte overhead to packets. Setting MTU to 1420 and MSS to 1380 prevents fragmentation. For a technical breakdown, see **[pfSense Networking and Routing](../knowledge-base/pfsense/networking-and-routing.md)**.
- **IPv4 Address:** Input the IP provided by the Mullvad API (e.g., 10.63.121.111/32).

### Phase D: Create Gateways

- Go to **System -> Routing -> Gateways**.
- Add a Gateway for the `MULLVAD_VPN_0` interface.
- **Name:** `MULLVAD_WG0_GW`.
- **Description:** `Mullvad WireGuard Gateway 0`.
- **Monitor IP:** Set to `1.1.1.1` for the first tunnel and `9.9.9.9` for the second.
  - *Rationale:* Each gateway requires a unique Monitor IP to avoid conflicting status reports. If pings fail, pfSense marks the specific tunnel as "Down" and triggers failover.

---

## III. Gateway Group: MULLVAD_FAILOVER

This group creates a virtual "super-gateway" to ensure the lab stays connected if one Mullvad server hangs.

- Go to **System -> Routing -> Gateway Groups**.
- **Group Name:** `MULLVAD_FAILOVER`.
- **Member 1:** `MULLVAD_WG0_GW` (Tier 1).
- **Member 2:** `MULLVAD_WG1_GW` (Tier 1).
- **Trigger Level:** High Latency or Packet Loss.
- *Rationale:* This triggers a switch if the tunnel is performing poorly. See **[pfSense Networking and Routing](../knowledge-base/pfsense/networking-and-routing.md)** for more on policy-based triggers.

---

## IV. Firewall Kill-Switch (Hard Fail-Closed)

This ensures traffic drops immediately if the VPN is unavailable, preventing leaks.

- **Disable Rule Skipping:**
  - Go to **System -> Advanced -> Miscellaneous**.
  - Ensure **"Skip rules when gateway is down"** is **UNCHECKED**.
  - *Rationale:* This forces pfSense to keep blocking rules active even if the gateway is missing. For more, see **[[kb/pfsense/networking-and-routing.md]]**.
- **Create Client Alias:**
  - Go to **Firewall -> Aliases**.
  - **Name:** `VPN_Clients`.
  - **IPs:** Add the Servarr LXC IP (`192.168.1.150`).
- **Apply Policy Routing and Kill-Switch (LAN Rules):**
  - Go to **Firewall -> Rules -> LAN**.
  - **Rule 1 (Pass):** Action: Pass | Source: `VPN_Clients` | Gateway: `MULLVAD_FAILOVER` | Description: `Pass VPN_Clients to Mullvad VPN Group`.
  - **Rule 2 (Block):** Action: Block | Source: `VPN_Clients` | Destination: Any | Description: `Kill-switch: Block VPN_Clients from WAN if VPN is down`.

---

## V. Verification

- Go to **Diagnostics -> States -> Reset States**.
- Visit [mullvad.net/check](https://mullvad.net/check) from the Servarr LXC.
- Confirm status is **Protected** and check that **DNS Hijacking** is not detected.

---

**Knowledge Base References:**

- **[pfSense Networking and Routing](../knowledge-base/pfsense/networking-and-routing.md)**
- **[pfSense DNS and Security](../knowledge-base/pfsense/dns-and-security.md)**

Proceed to the next file:
-> **[02-pfsense-hardened-dns.md](./02-pfsense-hardened-dns.md)**
