# Compatibility

## Tested Configurations (v2.6)

### Operating Systems

| OS | Edition | Build | Status | Notes |
|----|---------|-------|--------|-------|
| Windows 11 | Pro Insider Preview | 26200 | Fully tested | Primary development platform |
| Windows 11 | Pro | 22621+ | Compatible | Full test suite |
| Windows 11 | Home | 22621+ | Compatible | Some tests require admin |
| Windows 10 | Pro | 19041+ | Compatible | Full test suite |
| Windows 10 | Home | 19041+ | Compatible | Some tests require admin |
| Windows Server 2022 | Standard | — | Compatible | GPU tests may be limited |
| Windows Server 2019 | Standard | — | Compatible | GPU tests may be limited |

PowerShell 5.1 (ships with Windows 10/11) is the primary target. PowerShell 7 is supported but not required.

---

## Tested Hardware (v2.6 test run)

### CPU
| Model | Cores / Threads | Status |
|-------|----------------|--------|
| Intel Core i9-13900K | 24C / 32T | Tested |
| Intel Core i7-12700K | 12C / 20T | Compatible |
| AMD Ryzen 9 5900X | 12C / 24T | Compatible |

### GPU
| Model | VRAM | Status | Notes |
|-------|------|--------|-------|
| NVIDIA GeForce RTX 3080 | 10 GB | Tested | nvidia-smi, VRAM accurate |
| Intel UHD Graphics 770 | 2 GB (shared) | Tested | iGPU detected correctly |
| AMD Radeon RX 6800 XT | 16 GB | Compatible | Registry detection |
| NVIDIA GeForce RTX 4090 | 24 GB | Compatible | VRAM via REG_BINARY fix |

### Storage
| Type | Interface | Status |
|------|-----------|--------|
| NVMe SSD | PCIe 4.0 | Tested (1373 MB/s write, 3996 MB/s read) |
| SATA SSD | SATA III | Compatible |
| HDD | SATA | Compatible |
| USB Flash | USB 3.x | Compatible (script drive) |

### Network Adapters
| Type | Status | Notes |
|------|--------|-------|
| Intel / Realtek Gigabit Ethernet | Full support | Physical NIC check applies |
| Wi-Fi (802.11n / ax) | Full support | Excluded from "slow NIC" recommendation (v2.6) |
| VMware VMnet | Full support | Excluded from physical NIC check |
| Mullvad VPN | Full support | Excluded from physical NIC check |
| Tailscale | Full support | Excluded from physical NIC check |
| WireGuard | Full support | Excluded from physical NIC check |

---

## Speed Test Compatibility

The v2.6 engine uses a three-method cascade:

| Method | TLS | VPN Compatible | Notes |
|--------|-----|---------------|-------|
| curl.exe (primary) | 1.3 | Yes | WinHTTP/Schannel; ships with Windows 10 1803+ |
| BITS (fallback) | 1.3 | Yes | Background Intelligent Transfer Service |
| Invoke-WebRequest (last resort) | 1.2/1.3 | Partial | .NET; may fail under TLS-intercepting proxies |

curl.exe is available on Windows 10 version 1803 and later. On older systems, BITS is the primary method.

---

## Known Limitations

| Area | Limitation | Workaround |
|------|-----------|------------|
| coreinfo output | CPU topology map lines may not survive the output cleaner (format variation) | View full coreinfo output manually |
| GPU-OpenGL | OpenGL ICD registry entries not always present | Not a failure — entry is omitted if no data found |
| DISM/SFC | Require admin; skipped otherwise | Run via SystemTester.bat as Administrator |
| Energy report | Requires admin; 15-second scan | Run via SystemTester.bat as Administrator |
| Non-English Windows | DISM/SFC text matching bypassed; relies on exit codes | Fixed in v2.6 via language-neutral exit code embedding |
| Windows Server | Some GPU/display tests may return limited data | Expected — server SKUs often lack display hardware |

---

## VPN Compatibility (v2.6)

Tested under Mullvad VPN (WireGuard protocol) with all tests passing. The following VPN software is excluded from the "slow physical NIC" recommendation engine:

Mullvad, Tailscale, WireGuard, OpenVPN, TAP-Windows, Cisco AnyConnect, GlobalProtect, Fortinet/FortiClient, NordLynx, Pulse, ProtonVPN, Surfshark, ZeroTier
