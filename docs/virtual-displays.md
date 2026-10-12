# Virtual Display Management & DXGI Capture

This document details the configuration of virtual display drivers, DXGI desktop duplication bindings, custom resolution timings, and display scaling in multi-client Apollo setups.

---

## 1. Virtual Display Drivers (VDD)

High-performance remote streaming requires host displays that match the exact aspect ratio, native resolution, and refresh rate of client screens without requiring physical dummy HDMI/DisplayPort dongles.

Supported drivers:
- **Apollo Virtual Display Driver** (Built into Apollo)
- **IddSampleDriver** (Indirect Display Driver Sample)
- **Parsec Virtual Display Driver**

### Enabling in Sunshine / Apollo
In each profile's `sunshine.conf`, the virtual display subsystem is governed by:
```ini
always_use_virtual_display = enabled
dd_resolution_option = manual
dd_refresh_rate_option = manual
dd_manual_resolution = 1920x1440
dd_manual_refresh_rate = 120
double_refreshrate = disabled
```

---

## 2. Hardware Profiles & Panel Matchings

| Profile | Target Device | Native Panel Specs | DXGI Output ID | Scaling |
| :--- | :--- | :--- | :--- | :--- |
| **`ipad-wired`** | iPad Pro 13" M4 | 2752x2064 (Rendered: 1920x1440) @ 120Hz ProMotion | `\\.\DISPLAY20` | 150% |
| **`imac-direct`** | iMac 27" 5K | 5120x2880 @ 60Hz 16:9 | `\\.\DISPLAY21` | 200% |
| **`ipad-roam`** | iPad Pro 13" M4 | 1920x1440 @ 120Hz ProMotion | `\\.\DISPLAY20` | 150% |

### Why 1920x1440 for iPad Pro M4?
- The iPad Pro 13" panel has an exact 4:3 aspect ratio.
- 1920x1440 provides an exact integer scaling factor for crisp text and UI elements while keeping NVENC encode times under 2.5ms at 120 frames per second.
- Setting 120Hz in the driver matches Apple ProMotion, eliminating frame judder and cursor stutter.

---

## 3. Single-Display Handover Safety

Notice that **Instance 1 (iPad Wired)** and **Instance 3 (iPad Roam)** both bind to `\\.\DISPLAY20`:
- **Physical Reason**: Only one virtual display is needed for the iPad, whether docked at the desk or carried across the room.
- **Capture Conflict Prevention**:
  - The Windows Desktop Duplication API (DXGI) does not permit two simultaneous processes to capture the same display output at the same instant.
  - When switching from Wired to Wireless roaming, Moonlight terminates the session on Instance 1 before opening Instance 3.
  - The `launch_and_heal.ps1` supervisor ensures both instances share clean process lifecycles without locking the virtual display device.

---

## 4. Automating DPI Scaling

When Windows creates an indirect virtual display, it often defaults to 100% DPI scaling, rendering icons and text microscopic on high-DPI panels.

### Recommended Settings
- **iPad Pro 13" (1920x1440)**: **150%** scaling provides the optimal balance of UI size, touch target accuracy, and screen workspace.
- **iMac 5K (5120x2880)**: **200%** scaling provides standard Retina desktop sizing.

### Applying Scaling via PowerShell
Using the Windows DisplayConfig API or utilities like `SetDpi`:
```powershell
# Set 150% scaling on display index 2
.\SetDpi.exe 150 2
```
Or via Windows Display Settings under **Scale & layout**.
