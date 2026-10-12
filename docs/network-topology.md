# Network Topology & Routing Architecture

This document describes the network architecture, routing policies, and firewall rules utilized by **Apollo Multi-Screen Bridge** to achieve deterministic wired-first streaming with seamless wireless roaming.

---

## 1. High-Level Architecture Overview

Modern high-refresh, ultra-high-resolution streaming (e.g., 5K 60Hz and 1920x1440 120Hz) requires gigabit throughput with sub-millisecond network jitter. To avoid interference, bandwidth bottlenecks, and Moonlight client confusion, traffic is segregated into dedicated instances and network pathways:

```
+---------------------------------------------------------------------------------------+
|                                    WINDOWS HOST                                       |
|                                                                                       |
|  [Instance 1: iPad Wired]         [Instance 2: iMac 5K]        [Instance 3: iPad Roam]|
|    Port: 47989, WebUI: 47990        Port: 48089, WebUI: 48090    Port: 48189, WebUI: 48190|
|    UniqueID: UUID-ALPHA             UniqueID: UUID-BETA          UniqueID: UUID-GAMMA |
|    Bound: \\.\DISPLAY20             Bound: \\.\DISPLAY21         Bound: \\.\DISPLAY20 |
+---------------------------------------------------------------------------------------+
            |                                  |                            |
    (Direct Cat 8 / USB-C)             (Direct Cat 8 RJ45)           (Wi-Fi / Tailscale)
   Subnet: 192.168.3.0/24             Subnet: 192.168.2.0/24         Subnet: 192.168.1.0/24
    Metric: 5 (High Priority)          Metric: 20                   Metric: 30 (Fallback)
            |                                  |                            |
            v                                  v                            v
    [ iPad Pro M4 (Docked) ]           [ iMac 27" 5K Retina ]        [ iPad Pro M4 (Mobile) ]
```

---

## 2. Deterministic Wired Priority via Interface Metrics

### The Problem
When a client device (such as an iPad) has both Wi-Fi enabled and a direct USB-C Ethernet connection docked:
1. Windows Network stack defaults to balancing or using the primary default gateway interface.
2. If packets route through the home Wi-Fi access point, round-trip latency spikes from **0.2ms** to **8-15ms**, and frames drop during bursts.
3. Turning off Wi-Fi on the client device every time it docks is cumbersome and breaks AirDrop, Apple Pencil handoff, and notifications.

### The Solution: Interface Metric 5
Windows evaluates routes using metric costs. Lower metric numbers mean higher priority.
- By setting the host's direct Ethernet interface (`Ethernet 4`) to **InterfaceMetric 5**:
  ```powershell
  Set-NetIPInterface -InterfaceAlias "Ethernet 4" -InterfaceMetric 5
  ```
- Windows guarantees that any traffic directed towards the 192.168.3.x subnet flows exclusively through the direct 1Gbps / 2.5Gbps cable.
- The supervisor script (`launch_and_heal.ps1`) enforces this metric on every launch to defend against Windows network reset events.

---

## 3. Moonlight Host Collision Prevention

Moonlight identifies streaming hosts using the **`uniqueid`** attribute retrieved from the HTTP `/serverinfo` discovery endpoint.

### Why Collisions Happen
If two Sunshine instances share the same `sunshine_state.json` file or use identical GUIDs:
1. Moonlight receives the discovery broadcast from both ports or IP addresses.
2. Moonlight recognizes the same UniqueID and assumes it is the same physical computer advertising multiple IPs.
3. Moonlight merges the entries or overwrites the IP address, causing the user's manual tile to flip uncontrollably between wired and wireless.

### Isolated Machine Identity
Each instance configured by `apollo-multiscreen-bridge` is provisioned with:
- An isolated directory (`config/`, `config2/`, `config3/`).
- A distinct, cryptographically unique GUID in `sunshine_state.json`.
- A dedicated port offset ($P_1 = 47989, P_2 = 48089, P_3 = 48189$).

In the client's Moonlight UI, they appear as three separate, dedicated tiles:
- **`Apollo-iPad Wired`**: Connects directly via 192.168.3.1.
- **`Apollo-iMac`**: Connects directly via 192.168.2.1.
- **`Apollo-iPad Roam`**: Connects via Wi-Fi (192.168.1.x) or Tailscale (100.x.y.z).

---

## 4. Port Offset Formula

Sunshine requires multiple TCP and UDP ports for discovery, WebUI administration, RTSP session negotiation, and low-latency video/audio UDP streams.

For any base port $P$:
| Service | Protocol | Formula | Instance 1 (iPad Wired) | Instance 2 (iMac Direct) | Instance 3 (iPad Roam) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **HTTPS WebUI** | TCP | $P - 5$ / $P + 1$ | 47984 / 47990 | 48084 / 48090 | 48184 / 48190 |
| **HTTP Discovery** | TCP | $P$ | 47989 | 48089 | 48189 |
| **RTSP Handshake** | TCP | $P + 21$ | 48010 | 48110 | 48210 |
| **Video Stream** | UDP | $P + 9$ | 47998 | 48098 | 48198 |
| **Audio Stream** | UDP | $P + 11$ | 48000 | 48100 | 48200 |
| **Control Packets** | UDP | $P + 10$ | 47999 | 48099 | 48199 |

---

## 5. Automated Windows Firewall Isolation

To prevent the wired profile from broadcasting over the household Wi-Fi network, `bootstrap.ps1` injects Windows Firewall interface-scoped rules:
- **Instance 1 (Wired Exclusive)**: Ports `47989`, `47990`, `47998-48010` are blocked on the `Wi-Fi` adapter interface. Traffic is only permitted across `Ethernet 4`.
- **Instance 2 & 3**: Ports are open across all adapters with standard inbound allow policies.
