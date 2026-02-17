Here’s a clear, structured summary of my plan:

---

## 🔧 Core Goals
- Flash **OpenWrt** on the Orbi RBR40 to maximize router functionality and gain experience.
- Use **Tailscale** (with subnet routing), **SSH access**, **VPN**, and **AdGuard/Pi-hole**.
- Deploy **Orbi RBR40** as the main router, **RBS50** as a switch/AP, and **Deco M9 Plus** units as APs for IoT and office coverage.

---

## 🏠 Condo Layout & Connectivity
- **1100 sqft condo**, rectangular layout with living room, kitchen, dining, hallway, bedrooms, and office.
- **ISP coax line** enters in the living room; secondary coax run to master bedroom (less stable).
- **MoCA adapters** provide wired backhaul between living room and master bedroom.
- Internet speed: **500/25 Mbps**.

---

## 📡 Current Network Setup
- **Main Deco** in master bedroom (with modem).
- **Deco satellite** in office (wireless backhaul) → 4-port switch for desktop, printer, docking station.
- **Deco satellite** in living room (wired backhaul via MoCA) → 5-port switch for TV, streaming device.
- **8-port switch** in master bedroom for TV, streaming device, MoCA adapter.
- **Home Assistant VM** hosted on office desktop.
- **Wi-Fi settings**: fast roaming enabled, beamforming disabled (to avoid sticky connections).
- **Networks**:
  - Main: 2.4 + 5 GHz (TVs, streaming, computers, Alexa, Google Home).
  - IoT: 2.4 GHz only (lightbulbs, switches).
- **Static IPs** for devices; DHCP 101–250; Cloudflare DNS (1.1.1.1, 1.0.0.1).
- **Issue**: IoT devices unstable (unknown/reconnected status), affecting automations.

---

## 📌 Planned Integration
### Living Room (Router Core)
- Modem → **RBR40 (WAN)**.
- RBR40 LAN ports:
  - LAN 1 → Deco 1 (Main AP).
  - LAN 2 → MoCA Adapter → Master Bedroom.
  - LAN 3 → 8-port switch (TV, streaming, etc.).

### Master Bedroom
- MoCA Adapter → Deco 3 (wired AP).
- Deco 3 LAN → RBS50 (acting as switch).
- RBS50 LAN → 4-port switch (TV, streaming).
- Deco 3 ↔ Deco 2 (Office) via wireless backhaul.

---

## 📶 Wi-Fi Strategy
- **Two networks**:
  - **Main network**: 5 GHz only, WPA2/WPA3, advanced controls (channels, power).
  - **IoT network**: 2.4 GHz only, WPA/WPA2 for legacy devices.
- **Orbi (OpenWrt)**: broadcast **main 5 GHz network** only.
- **Deco units**: broadcast **IoT 2.4 GHz network** only.
- Fine-tune channels/width on Orbi to minimize overlap and improve roaming.
- Lock IoT devices to nearest Deco AP for stability.

---

## 🛠️ OpenWrt Features to Leverage
- **Channel selection & transmit power control** (better roaming, less overlap).
- **VLANs**:
  - Separate IoT traffic from personal devices for security and performance.
  - Example: VLAN 10 for IoT, VLAN 20 for personal devices, VLAN 30 for guest.
- **Firewall rules**: restrict IoT devices from accessing sensitive LAN resources.
- **VPN/Tailscale**: secure remote access and subnet routing.
- **AdGuard/Pi-hole**: centralized DNS filtering for ads and trackers.

---

## ✅ Final Vision
- **Orbi RBR40 (OpenWrt)**: main router, 5 GHz personal network, VLAN segmentation, advanced controls.
- **Orbi RBS50**: switch/AP for wired devices in master bedroom.
- **Deco M9 Plus**: dedicated IoT 2.4 GHz mesh, wired backhaul where possible, wireless in office.
- **Stable, segmented network**: personal devices fast and secure on Orbi, IoT devices isolated on Deco, wired backhaul ensures reliability.

---

👉 In short: i'm building a **dual-network setup** where Orbi (OpenWrt) handles the high-performance, secure 5 GHz personal network, while Deco covers IoT with 2.4 GHz. VLANs on OpenWrt will give extra control and isolation, MoCA ensures wired stability, and I’ll fine-tune channels to minimize overlap.  

<img width="1024" height="1024" alt="image" src="https://github.com/user-attachments/assets/f54c6f87-f073-4309-aca7-76da12ae7c17" />
