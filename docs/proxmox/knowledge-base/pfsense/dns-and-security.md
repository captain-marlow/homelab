# pfSense DNS and Security

This manual explains the mechanics of the "Hardened DNS" architecture. It details how we combine encryption, redirection, and API-level service configuration to ensure that no DNS queries leak to the ISP or third parties, even if a device attempts to bypass your settings.

---

## I. DNS-over-TLS (DoT) with Quad9

Standard DNS travels in plain text over port 53, making it visible to your ISP. We use **DNS-over-TLS** to wrap these queries in an encrypted tunnel (Port 853).

- **The Upstream**: Quad9 (`9.9.9.9`) is used for its "Threat Blocking" feature, which prevents resolution of known malicious domains at the DNS level.
- **The Mechanic**: In **Services -> DNS Resolver**, enabling "Forwarding Mode" and "SSL/TLS for Outgoing DNS Queries" forces the Unbound resolver to act as a TLS client.
- **The Fail-Closed Logic**: By setting "Outgoing Network Interfaces" to only your VPN tunnels, the DNS Resolver will fail to resolve entirely if the VPN is down. This prevents a "DNS Leak" where the system might otherwise revert to the WAN to find an answer.

---

## II. Mullvad DNS Hijacking (API Level)

By default, Mullvad transparently intercepts all traffic on Port 53 and redirects it to their own internal DNS servers. While secure, this breaks our ability to use Quad9 and pfBlockerNG.

To use our own custom DNS, we must use the Mullvad API to register our WireGuard Public Key with the `hijack_dns` flag set to `false`.

- **Mechanism**: When `hijack_dns` is disabled via API, the Mullvad exit node treats Port 53 like any other traffic, allowing our encrypted Port 853 queries (or redirected Port 53 queries) to pass through to Quad9.
- **Verification**: If the [Mullvad Check](https://mullvad.net/check) tool shows "DNS Hijacking Detected," the API call was either unsuccessful or the WireGuard tunnel was not re-handshaked after the change.

---

## III. NAT Redirection (The "Magic" Rule)

Many devices (Chromecasts, Smart TVs, and certain mobile apps) have hardcoded DNS servers like `8.8.8.8` (Google) or `1.1.1.1` (Cloudflare). They will ignore the DNS server provided by your DHCP.

We use a **NAT Port Forward** to intercept these rogue queries:

1. **Match**: Any packet on the LAN interface where the Destination Port is `53` and the Destination IP is **NOT** `192.168.1.1`.
2. **Action**: Transparently rewrite the destination to `192.168.1.1` (pfSense).
3. **Result**: The device thinks it is talking to Google, but it is actually receiving a filtered, encrypted response from your local pfSense resolver.

---

## IV. pfBlockerNG-devel (Python Mode)

We utilize **Python Mode** for DNS Blocking (DNSBL). Unlike the legacy mode which uses complex firewall aliases, Python Mode hooks directly into the Unbound resolution process.

- **Performance**: It is significantly lighter on CPU and RAM because it doesn't require thousands of firewall states.
- **Regex Support**: Allows for advanced blocking patterns (e.g., blocking all `.top` or `.zip` TLDs).
- **Hard-Coded Bypass Prevention**: Because it lives inside the resolver, combined with the NAT Redirection above, no device can escape the ad-blocker.

---

## V. Security Verification

To confirm your DNS is truly "Hardened," use the following tests:

1. **Standard Leak Test**: Visit [dnsleaktest.com](https://www.dnsleaktest.com). You should only see Quad9 (WoodyNet) servers.
2. **Hijack Test**: Visit [mullvad.net/check](https://mullvad.net/check). DNS Hijacking should show as "No."
3. **Redirection Test**: From a terminal, run `nslookup google.com 8.8.8.8`. If you have a blocklist active, try to resolve a blocked domain via 8.8.8.8. If it returns `0.0.0.0` or your block page, the NAT redirection is working.

---

**Related Documentation:**

- **[(02) pfSense Hardened DNS](../../setup/02-pfsense-hardened-dns.md)**
- **[pfSense Networking and Routing](./networking-and-routing.md)**
- **[Proxmox Networking and Firewall](../proxmox/networking-and-firewall.md)**
