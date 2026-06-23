# 02 — pfSense Hardened DNS

This document outlines the configuration for a **Hard Fail-Closed DNS architecture**. By the end of this setup, all DNS queries from your lab will be encrypted via **DNS-over-TLS (DoT)**, filtered for malicious content, and strictly prohibited from leaking out of your standard WAN interface.

---

## I. System DNS and Global Settings

First, we define the global upstream providers. We use **Quad9** for its strong privacy stance and built-in threat intelligence filtering.

- Go to **System -> General Setup**.
- **DNS Servers:**
  - `9.9.9.9` | **Hostname:** `dns.quad9.net`
  - `149.112.112.112` | **Hostname:** `dns.quad9.net`
- **DNS Server Override:** Uncheck "Allow DNS server list to be overridden by DHCP/PPP on WAN".
  - *Rationale:* This ensures pfSense never ignores your secure Quad9 settings in favor of whatever DNS your ISP pushes via the WAN connection.
- **DNS Resolution Behavior:** Use local DNS, fall back to remote.

---

## II. Hardened DNS Resolver (Unbound)

The DNS Resolver is the "brain" of your name resolution. We configure it to use encryption for outgoing queries and restrict its "vision" to only the VPN tunnels.

- Go to **Services -> DNS Resolver -> General Settings**.
- **Enable:** Checked.
- **Listen Port:** `53`.
- **Enable Forwarding Mode:** Checked (Required for Quad9 DoT).
- **Use SSL/TLS for Outgoing DNS Queries:** Checked.
- **Network Interfaces:** Select `LAN` and `Localhost`.
- **Outgoing Network Interfaces:** Select **ONLY** `MULLVAD_VPN_0` and `MULLVAD_VPN_1`.
  - *Rationale:* This is the core of the **Hard Fail-Closed** design. By excluding the WAN interface here, if your VPN tunnels are down, the Resolver has no path to the internet. DNS will stop immediately rather than failing back to your insecure WAN.

---

## III. The "Magic" NAT Redirection Rule

Even if you tell clients to use pfSense for DNS, some devices (like smart TVs or hardcoded apps) try to bypass your settings by talking directly to Google (`8.8.8.8`). This rule intercepts that "hijack" attempt and forces it back to your secure Resolver.

- Go to **Firewall -> NAT -> Port Forward**.
- **Description:** `Standardize DNS: Force LAN to pfSense`.
- **Interface:** `LAN`.
- **Protocol:** `TCP/UDP`.
- **Destination:** `Any`.
- **Destination Port Range:** `53`.
- **Redirect Target IP:** `192.168.1.1`.
- **Redirect Target Port:** `53`.
- **NAT Reflection:** `Disable`.
- **Filter Rule Association:** `Add associated filter rule`.
- *Technical Reference:* For more on how this prevents "shadow DNS" leaks, see .

---

## IV. pfBlockerNG (Python Mode)

We use pfBlockerNG to provide network-wide ad and malware blocking. Running in **Python Mode** provides the best performance and integration with the Unbound Resolver.

- Go to **Firewall -> pfBlockerNG**.
- **Enable pfBlockerNG:** Checked.
- **DNSBL:** Enabled.
- **DNSBL Mode:** `Unbound Python`.
- **Lists:** Add your preferred blocklists (e.g., StevenBlack, OISD).
  - *Rationale:* Python mode allows pfBlockerNG to hook directly into the Unbound resolution process, making it faster and more resource-efficient than traditional entry-parsing modes.

---

## V. Verification

- Go to **Diagnostics -> States -> Reset States**.
- Visit [mullvad.net/check](https://mullvad.net/check) from a client machine.
- **Confirm Results:** - You should see **"No DNS Leaks"**.
  - Note: The check might show Quad9 servers; this is expected as they are your chosen secure providers, not your ISP's servers.

---

**Knowledge Base References:**

- `kb/pfsense/networking-and-routing.md`
- `kb/pfsense/dns-and-security.md`

Proceed to the next file:
-> **[03 PVE Host Baseline](./03-pve-host-baseline.md)**
