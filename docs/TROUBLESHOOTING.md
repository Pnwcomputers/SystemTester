# Troubleshooting

## Quick Fixes

| Symptom | Solution |
|---------|----------|
| Script won't run | Use launcher Menu Option 3 to set execution policy, or run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force` |
| "Access denied" errors | Right-click `SystemTester.bat` and choose "Run as administrator" |
| Sysinternals tools not found | Use launcher Menu Option 5 to auto-download (~35 MB from Microsoft) |
| Reports not appearing | Check `<script dir>\Reports\` subfolder — auto-created on first run |
| GPU tests all SKIPPED | Install NVIDIA/AMD drivers; nvidia-smi ships with NVIDIA drivers |

---

## Network

### Speed test fails or shows 0 Mbps
**v2.6 approach:** The speed test tries curl.exe (WinHTTP/Schannel) first, then BITS, then Invoke-WebRequest. If all three fail:
- Check that outbound HTTPS (port 443) is not blocked by a firewall or security appliance
- Try disabling VPN temporarily — Mullvad, WireGuard, and similar VPNs add significant overhead and occasionally block test endpoints
- Check `%TEMP%` for a leftover `speedtest_*.tmp` file and delete it

### Speed test shows very low speed (under 5 Mbps)
This is usually accurate — the test measures real throughput to a public server including VPN overhead. If it seems unexpectedly low:
- Run the test twice; the first run may be slower if curl.exe is downloading through a cold VPN tunnel
- Check your VPN server location — a geographically distant server adds latency and can reduce throughput

### Latency test shows high RTT (100 ms+)
Expected when a VPN is active. PsPing and Test-NetConnection both measure round-trip time to 8.8.8.8 through whatever path your traffic takes, including VPN routing.

### VMware / Hyper-V / VPN adapters flagged as slow NICs
**Status:** Fixed in v2.5 / v2.6. Virtual and VPN adapters (VMware, Hyper-V, Tailscale, Mullvad, WireGuard, OpenVPN, and others) are excluded from the physical NIC speed check. If you still see this, check whether your adapter name contains one of the exclusion patterns.

### Wi-Fi adapter flagged as slow NIC
**Status:** Fixed in v2.6. Adapters whose names contain `Wi-Fi`, `Wireless`, or `WLAN` are now excluded from the "Upgrade to Gigabit Ethernet" recommendation.

---

## Reports

### Reports saved in wrong location
Reports are saved to `<script directory>\Reports\`, not the script root itself. The subfolder is auto-created on first report generation.

Full path: `<script dir>\Reports\SystemTest_Clean_YYYYMMDD_HHMMSS.txt`

### Reports show garbled characters
**Status:** Fixed in v2.5. Reports use ASCII encoding and plain `*` / `->` characters. If you see `â€¢` or `â†'`, you are looking at an old report from v2.4 or earlier.

### clockres or du sections show license text instead of data
**Status:** Fixed in v2.6. Both tools are now passed `-accepteula` automatically.

### autorunsc section shows usage/help text instead of entries
**Status:** Fixed in v2.6. The argument was `-a -c` which caused autorunsc to consume `-c` as a type-selection character, leaving no CSV flag. Now uses `-c` only (default logon entries, CSV format).

---

## OS Health

### DISM reports "The component store is repairable"
This is a real finding — Windows has detectable corruption that can be repaired. Run:
```
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow
```
Then reboot and re-run SystemTester to confirm resolution.

### DISM/SFC scans take a very long time
Expected. DISM `/ScanHealth` typically takes 5–15 minutes; SFC can take similar time on large system volumes. Do not interrupt these scans.

### DISM/SFC shows SKIPPED
Both require administrator rights. Re-run via `SystemTester.bat` (Run as Administrator).

---

## Hardware Events (WHEA)

### "Hardware errors detected" on a healthy system
**Status:** Fixed in v2.6. WHEA Level 4 informational events (including the "WHEA-Logger started" event that fires on every Windows boot) no longer trigger a warning. The filter now requires Level ≤ 3 (Warning, Error, or Critical).

If the warning appears after this fix, it represents a genuine hardware event worth investigating — check Event Viewer > Windows Logs > System, filter by source "Microsoft-Windows-WHEA-Logger".

---

## Windows Update

### Windows Update shows "Service StartType: Manual" but service is running
This is normal on Windows 10/11. The Windows Update service (`wuauserv`) is trigger-started on demand and idles in a Stopped state between operations. StartType=Manual is the default and expected configuration. Only StartType=Disabled triggers a recommendation.

### Windows Update search hangs for 5+ minutes
This is a known Windows behavior when the update catalog is large or the service has not been contacted recently. Allow up to 10 minutes before concluding it has failed. If it fails consistently, check Windows Update logs in Event Viewer.

---

## GPU

### NVIDIA GPU tests show SKIPPED
Install or reinstall NVIDIA drivers from nvidia.com. `nvidia-smi.exe` ships with the driver package; SystemTester looks for it in `C:\Windows\System32\` and `C:\Program Files\NVIDIA Corporation\NVSMI\`.

### GPU VRAM shows 4 GB on a higher-capacity card
Some driver versions store VRAM as a `REG_BINARY` value rather than `REG_QWORD`. Fixed in v2.6 — `Get-AccurateVRAM` now detects the registry type and converts via `BitConverter`.

### Dual-GPU system shows incorrect VRAM
On multi-GPU systems (e.g. discrete NVIDIA + Intel iGPU), the per-adapter VRAM usage from Windows performance counters is unreliable. SystemTester reports per-adapter VRAM capacity and uses the `GPU-Memory-Total` aggregate entry for system-wide utilization.

### GPU stress test tools not available
Use batch launcher Menu Option 6 → Option 5 to automatically download MSI Afterburner and FurMark directly to the `Tools\` folder. Alternatively, download manually:
- **MSI Afterburner**: msi.com/Landing/afterburner
- **FurMark**: geeks3d.com/furmark

---

## Sysinternals Tools

### Tools fail with EULA prompt
Sysinternals tools display a EULA on first run. SystemTester automatically passes `-accepteula` to supported tools. If a tool still shows the EULA, accept it manually once — acceptance is stored in the registry (`HKCU\Software\Sysinternals\<ToolName>\EulaAccepted`).

### Tool integrity verification (Menu Option 4) fails
Re-download Sysinternals Suite via Menu Option 5. A failed verification usually means a tool was partially downloaded or is from a different distribution.

### coreinfo shows empty output
coreinfo output filtering only retains lines matching processor/cache/feature patterns. On some processor configurations, coreinfo's topology map uses formats that don't match the filter. The tool still ran successfully — the architecture data simply didn't survive the cleaner.

---

## Expected Test Durations

| Test | Expected Duration |
|------|-------------------|
| CPU Performance (synthetic) | ~10 seconds |
| DirectX diagnostics (dxdiag) | 15–50 seconds |
| Power / Energy report | ~15 seconds (admin only) |
| Windows Update search | 30–120 seconds |
| DISM /ScanHealth | 5–15 minutes (admin only) |
| SFC /scannow | 5–15 minutes (admin only) |

---

## Still Stuck?

- Open a [GitHub Issue](../../issues) — include OS build, GPU type, admin status, and the full error message from the report
- Commercial support: jon@pnwcomputers.com / 360-624-7379
