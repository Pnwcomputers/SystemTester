# Portable Sysinternals Winodws System Testing Utility

<p align="center">
  <img src="assets/systemtester.png" alt="Thumb-drive friendly, no-install Windows hardware health check toolkit powered by Sysinternals and PowerShell." width="600"/>
</p>

![Automation Level](https://img.shields.io/badge/Automation-Zero%20Touch-green)
![Windows Support](https://img.shields.io/badge/Windows-10%20%7C%2011-blue)
![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Enterprise Ready](https://img.shields.io/badge/Enterprise-Ready-purple)
![GitHub issues](https://img.shields.io/github/issues/Pnwcomputers/SystemTester)
![Maintenance](https://img.shields.io/badge/Maintained-Yes-green)
 
**Thumb-drive friendly, no-install Windows hardware health check toolkit** powered by **Sysinternals** and **PowerShell**.
 
A zero-dependency **PowerShell solution** that runs a comprehensive, curated set of Sysinternals and Windows diagnostic tools. It then processes the raw data to produce two essential reports: a **Clean Summary Report** (human-readable, de-noised, with recommendations) and a **Detailed Report** (cleaned tool outputs).
 
**The essential utility for:**
* Field diagnostics and client handoff reports.
* Establishing a system baseline health check.
* Quickly identifying performance bottlenecks.
---
 
## What's New in v2.6
 
v2.6 is a quality and reliability release. The network speed test engine has been fully rewritten around `curl.exe` to resolve systematic TLS failures on modern endpoints. GPU tool downloads now work reliably via a new PowerShell function that fixes a batch-file parser bug triggered by Windows delayed variable expansion. A PNWC branded startup banner has been added. Thirteen bugs have been corrected, including six recommendation engine false positives and three tool output cleaner failures discovered during live test validation.
 
### New Features
 
- **PNWC Startup Banner**: Branded ASCII art header with version, contact info, and system context painted on launch; uses `Clear-Host` first to eliminate PowerShell startup noise; pure 7-bit ASCII (no UTF-8 box characters that mangle on older console hosts)
- **GPU Tool Auto-Download**: New `Invoke-GPUToolDownload` PS1 function handles MSI Afterburner and FurMark with a curl.exe → BITS → IWR cascade; batch launcher GPU Tools Manager now includes **Option 5** to trigger downloads directly without opening a browser
 
### Bug Fixes
 
| # | Area | Issue | Impact |
|---|------|--------|--------|
| 1 | Network Speed | All 3 test URLs failing: Cloudflare and OVH with TLS handshake errors; Hetzner hostname (`speed.hetzner.de`) retired — DNS resolution failed on all systems | **Critical**: speed test always failed |
| 2 | Network Speed | `.NET ServicePointManager` SSL bypass cannot resolve TLS 1.3 handshake failures — the bypass callback fires too late in the stack | High: fundamental architectural limit of the previous approach |
| 3 | Batch Launcher | `setlocal enabledelayedexpansion` consumed `!` characters in inline PowerShell strings before PowerShell received them, generating `Missing closing '}'` and missing Catch/Finally block parse errors | **Critical**: GPU tool downloads always failed |
| 4 | WHEA Events | Level 4 informational events (including "WHEA-Logger started" fired on every Windows boot) triggered "Hardware errors detected" recommendation | High: false positive on every healthy system after a reboot |
| 5 | Disk Performance | Multiline regex (`.*`) cannot cross newlines in PowerShell — Write/Read speeds stored on separate output lines were never matched | High: disk performance recommendations never fired on any system |
| 6 | Recommendations | Battery check matched the string `"No battery (desktop)"` on desktop systems | Medium: phantom laptop battery alert on desktops |
| 7 | Recommendations | 802.11n Wi-Fi adapters at 100 Mbps triggered "Upgrade to Gigabit Ethernet" recommendation | Medium: false positive on all wireless-connected clients |
| 8 | SMART Detection | `"Unhealthy"` `HealthStatus` from `Get-PhysicalDisk` not included in the recommendations pattern | Medium: actively failing drives not flagged |
| 9 | Windows Update | Two separate check blocks both fired `"ACTION: N update(s) pending"` for any `pendingCount > 0` | Low: doubled recommendations on most systems |
| 10 | Windows Update | After removing the duplicate early check, 1–5 pending updates produced no recommendation at all | Low: silent gap in coverage for minor pending counts |
| 11 | Tool Output | `clockres` and `du` not in the `-accepteula` list — full Sysinternals EULA text was written into the clock resolution and disk usage report sections instead of actual data | Medium: two report sections always empty/garbage |
| 12 | Security Analysis | `autorunsc` argument `-a -c` caused autorunsc to consume `-c` as the type-selection character for `-a` (codecs only), leaving no CSV flag — tool printed usage/help text instead of autorun entries | Medium: autorun entries never captured |
| 13 | Tool Output | `2>&1` stderr capture produced raw PowerShell `NativeCommandError` / `CategoryInfo` / `FullyQualifiedErrorId` formatting inside tool output sections | Low: error-object noise cluttering report output |
 
### What Changed Technically
 
**`Test-NetworkSpeed` (full rewrite)**
- Three-method cascade: **curl.exe** (primary) → **BITS** (fallback) → **Invoke-WebRequest** (last resort)
- curl.exe and BITS use WinHTTP/Schannel natively — completely unaffected by `.NET ServicePointManager` TLS limitations; both support TLS 1.3 out of the box
- Replaced retired `speed.hetzner.de` with `speedtest.tele2.net/10MB.zip` in the fallback slot
 
**`Invoke-GPUToolDownload` (new function)**
- Accepts `-Tool` (`"MSIAfterburner"` or `"FurMark"`) and `-TargetDir` parameters via new `$DownloadGPUTool` / `$DownloadDir` script params
- Batch launcher calls `-File "%SCRIPT_PS1%" -DownloadGPUTool "..." -DownloadDir "..."` — avoids all `!` delayed-expansion issues entirely
 
**Recommendation Engine: False positive fixes**
- WHEA: `Where-Object { $_.Level -le 3 }` — excludes Level 4 informational events (normal boot activity)
- Disk perf: split single `Write.*Read` multiline regex into two separate `if (-match "Write:")` / `if (-match "Read:")` blocks
- Battery: match narrowed from `"Battery"` to `"Battery: "` (colon + space) — only matches actual battery data lines
- NIC exclusion: added `Wi-Fi|Wireless|WLAN` to the virtual/non-physical adapter exclusion pattern
- Windows Update: consolidated into a single check block covering the full range: `>20` (WARNING), `>5` (INFO), `>0` (ACTION), `0` (GOOD)

**`Convert-ToolOutput` cleaner: Output quality fixes**
- Added `clockres` and `du` to the `-accepteula` injection list so clock resolution and disk usage sections show actual data instead of EULA text
- Added `NativeCommandError|CategoryInfo|FullyQualifiedErrorId|RemoteException|At .*\.ps1:` to the per-line skip pattern to strip PowerShell error-object formatting from `2>&1` captures
- Fixed `autorunsc` argument from `-a -c` to `-c`: `-a` was consuming `-c` as its selection character (codecs), leaving no CSV flag; default logon-entry CSV output now works correctly
---
 
## Key Capabilities
 
* **Zero-Install**: Portable execution from USB or network drives.
* **One-click Menu or Autorun**: interactive menu or `-AutoRun` parameter
* **Output Cleaner**: removes banners, EULA text, usage blocks for readable reports
* **Comprehensive Tests**: CPU, RAM, Disk, GPU, Network, OS Health, Windows Update status
* **Smart Hardware Detection**: Accurate VRAM reporting for modern GPUs (RTX 30/40/50-series) bypassing WMI 4GB limits.
* **Enhanced GPU Testing**: Multi-GPU support, NVIDIA/AMD vendor tools, display configuration
* **Network Speed & Latency**: Multi-URL fallback download test, PsPing integration, VPN-aware
* **Deep Diagnostics**: Automated DISM/SFC, Storage health, and Network throughput testing.
* **Tool Integrity Verification**: Digital signature checking for all Sysinternals tools
* **Smart Reporting**: timestamped Clean Summary + Detailed TXT reports with recommendations
* **Fully Portable**: runs from USB; no installation required
* **Graceful Degradation**: missing tools detected and skipped automatically
* **Robust Elevation Handling**: reliable admin detection (Windows Home compatible)
* **Auto-Download Tools**: built-in Sysinternals Suite and GPU tool downloader via batch launcher
* **Resilient Downloads**: Triple-redundant download engine (curl.exe > BITS > IWR) for speed tests and GPU tool downloads — native TLS 1.3 via WinHTTP/Schannel.
* **Windows Update Integration**: checks pending updates and service status
* **Modern PowerShell**: uses CIM instances (not deprecated WMI) for better performance
---
 
## 📋 Requirements
 
* **OS:** Windows 10/11 (Home/Pro/Enterprise & Windows Server supported)
* **PowerShell:** 5.1+ or PowerShell 7 (Standard Windows PowerShell)
* **Permissions:** Administrator rights recommended (some tests require elevation)
* **Internet**: Required for Option 5 (Sysinternals Download)
* **Sysinternals Tools:** Auto-downloadable via launcher or manual installation
  * *Note: v2.6 uses curl.exe (WinHTTP/Schannel) as the primary download engine for native TLS 1.3 support on all systems.*
* **GPU Tools (Optional):** NVIDIA drivers (nvidia-smi), AMD drivers, GPU-Z
---
 
## Recommended Folder Structure
 
```
SystemTester/
+-- SystemTester.ps1         # Main PowerShell script
+-- SystemTester.bat         # Batch launcher
+-- README.md
+-- LICENSE
+-- Sysinternals/            # Auto-created by launcher (Option 5)
|   +-- psinfo.exe
|   +-- coreinfo.exe
|   +-- pslist.exe
|   +-- handle.exe
|   +-- psping.exe           # Required for latency testing
|   +-- autorunsc.exe
|   +-- ... (60+ other tools)
+-- Tools/                   # GPU testing tools (optional)
|   +-- GPU-Z.exe            # Via launcher Option 6
+-- Reports/                 # Auto-created on first report generation
    +-- SystemTest_Clean_20260423_143022.txt
    +-- SystemTest_Detailed_20260423_143022.txt
    +-- energy-report.html   # If power test ran (admin only)
```
 
---
 
## Quick Start
 
### Option A: Batch Launcher (Recommended)
 
1. Download or clone this repository
2. Run `SystemTester.bat` (will request admin elevation)
3. Choose **Option 5** to auto-download Sysinternals Suite (first time only)
4. Choose **Option 6** to set up GPU testing tools (optional)
5. Choose **Option 1** for interactive menu or **Option 2** to run all tests
6. Reports are saved in the script directory
### Option B: Direct PowerShell
 
```powershell
# Interactive menu
powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1
 
# Run all tests automatically
powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1 -AutoRun
```
 
### First-Time Setup
 
If Sysinternals tools are missing:
1. **Automatic:** Use launcher Menu Option 5 to download (~35 MB)
2. **Manual:** Download from [live.sysinternals.com](https://live.sysinternals.com), extract to `.\Sysinternals\`
For enhanced GPU testing:
1. **NVIDIA GPUs:** Install latest NVIDIA drivers (includes nvidia-smi)
2. **AMD GPUs:** Install latest AMD drivers
3. **GPU-Z (Optional):** Use launcher Menu Option 6 -> 1 to download
---
 
## Test Suites (18 Categories)
 
| # | Category | Description | Key Tools |
|---|----------|-------------|-----------|
| 1 | System Information | OS details, computer info, clock resolution | `psinfo`, `clockres`, CIM |
| 2 | CPU Testing | Architecture, performance benchmarks | `coreinfo`, synthetic test |
| 3 | RAM Testing | Capacity, usage patterns | CIM queries |
| 4 | Storage Testing | Drives, performance, fragmentation | `du`, `contig`, read/write test |
| 5 | Process Analysis | Running processes, handles, process tree | `pslist`, `handle` |
| 6 | Security Analysis | Autorun entries, startup items | `autorunsc` |
| 7 | Network Analysis | Connectivity, latency, speed, adapters | `netstat`, `psping`, `Test-NetConnection` |
| 8 | OS Health | System file integrity, component store | `DISM`, `SFC` |
| 9 | Storage SMART | Drive health | `Get-PhysicalDisk` |
| 10 | SSD TRIM | TRIM enablement status | `fsutil` |
| 11 | Network Adapters | Link status, speed, IP/MAC | `Get-NetAdapter` |
| 12 | GPU (Enhanced) | Multi-GPU info, vendor tools, memory | CIM, `dxdiag`, `nvidia-smi` |
| 12a | Basic GPU Info | Details, displays, drivers, DirectX, OpenGL | CIM, `dxdiag` |
| 12b | Vendor-Specific | NVIDIA/AMD metrics, temps, utilization | `nvidia-smi`, AMD registry |
| 12c | GPU Memory | VRAM capacity, usage, performance counters | CIM, perf counters |
| 13 | Power/Battery | Battery health, energy report | `powercfg`, WMI |
| 14 | Hardware Events | WHEA error logs (last 7 days) | Event Viewer |
| 15 | Windows Update | Pending updates, service status | Windows Update COM API |
 
### Network Testing (Option 7): v2.6 Changes
 
The speed test engine was fully rewritten in v2.6 after all three test URLs failed simultaneously:
 
* **Speed test method 1 — curl.exe**: Uses WinHTTP/Schannel directly; supports TLS 1.3 natively; completely unaffected by `.NET ServicePointManager` limitations that caused failures under Mullvad, WireGuard, and corporate TLS-inspection proxies
* **Speed test method 2 — BITS**: Background Intelligent Transfer Service also uses WinHTTP; TLS 1.3 capable; activates if curl.exe is unavailable
* **Speed test method 3 — Invoke-WebRequest**: .NET fallback with TLS workarounds; last resort only
* **URL updated**: Retired `speed.hetzner.de` (DNS failure) replaced with `speedtest.tele2.net/10MB.zip`
* **Adapter recommendations**: Wi-Fi, Wireless, and WLAN adapters added to the exclusion pattern — 802.11n at 100 Mbps no longer triggers "Upgrade to Gigabit Ethernet"
---
 
## Sample Output
 
### Clean Summary Report
```
=========================================
  SYSTEM TEST REPORT v2.6
  CLEAN SUMMARY
=========================================
Date: 04/23/2026 14:30:22
Computer: DESKTOP-ABC123
Admin: YES
 
SUMMARY:
  Total Tests: 33
  Success: 31
  Failed: 0
  Skipped: 2
  Success Rate: 93.9%
 
KEY FINDINGS:
-------------
 
SYSTEM:
  OS: Microsoft Windows 11 Pro 10.0.26200
  Architecture: 64-bit
  Computer: DESKTOP-ABC123
  Manufacturer: Micro-Star International Co., Ltd.
  Model: MS-7D30
  RAM: 63.73 GB
 
MEMORY:
  Total RAM: 63.73 GB
  Available: 42.07 GB
  Used: 21.66 GB
  Usage: 34%
 
DISK PERFORMANCE:
  Write: 200.51 MB/s
  Read: 222.35 MB/s
 
GPU:
  Name: NVIDIA GeForce RTX 3080
  Adapter RAM: 10 GB
  Driver Version: 32.0.15.9621
 
NETWORK SPEED:
  Active Link Speeds:
    Wi-Fi: 2.5 Gbps
    Mullvad: 100 Gbps
    Tailscale: 100 Gbps
  Internet Download Test:
    URL: https://speed.cloudflare.com/__down?bytes=10000000
    File Size: 9.54 MB
    Time: 0.84 sec
    Throughput: 906.7 Mbps (113.3 MB/s)
 
NETWORK LATENCY:
  Target: 8.8.8.8
  Test-NetConnection:
    Ping Succeeded: True
    Ping RTT: 12 ms
  PsPing Summary:
    Min: 11.2 ms
    Max: 14.7 ms
    Avg: 12.5 ms
 
WINDOWS UPDATE:
  Service: Running
  Pending: 0
  Pending Updates: None
 
RECOMMENDATIONS:
----------------
* GOOD: Low memory usage (34%) - plenty of RAM available
* GOOD: Windows is up to date
* INFO: GPU drivers are over 1 year old
  -> Update to latest drivers for best performance
  -> NVIDIA: GeForce Experience or nvidia.com
  -> AMD: amd.com/en/support
 
For detailed output, see: SystemTest_Detailed_20260423_143022.txt
```
 
Note: Report files use plain ASCII: bullets are `*` and arrows are `->`. This ensures correct display in Notepad, legacy terminals, and any text viewer without encoding configuration.
 
---
 
## Launcher Menu Options
 
The batch launcher (`SystemTester.bat`) provides:
 
1. **Run Interactive Menu**: Select individual tests (includes GPU sub-options 12, 12a, 12b, 12c)
2. **Run ALL Tests Automatically**: Complete system scan with auto-report
3. **Fix PowerShell Execution Policy**: Set CurrentUser to RemoteSigned
4. **Verify Tool Integrity**: Check digital signatures and file sizes of Sysinternals tools
5. **Download/Update Sysinternals Suite**: Auto-download from Microsoft (~35 MB); uses curl.exe for TLS 1.3 compatibility
6. **GPU Testing Tools Manager**: Download and manage GPU testing tools (sub-menu includes Option 5: Download GPU Tools Automatically — MSI Afterburner and FurMark via curl.exe)
7. **Help / Troubleshooting**: Comprehensive troubleshooting guide
8. **Exit**
---
 
## Troubleshooting
 
### Network speed test fails / SSL error
**Cause:** VPN or proxy performing TLS inspection (Mullvad, Tailscale, corporate proxy).
**Status:** Fixed in v2.5. The script now tries three different servers and bypasses certificate validation per-attempt.
If all three fail, check firewall rules blocking outbound HTTP/HTTPS.
 
### Latency test always fails with "Port" error
**Cause:** Bug in v2.21: an undefined `$targetPort` variable caused `Test-NetConnection` to receive `Port=0`, which Windows rejects.
**Status:** Fixed in v2.5.
 
### PsPing shows "Unable to parse latency results"
**Cause:** PsPing output formatting variation not matched by the old strict regex.
**Status:** Fixed in v2.5. If it still shows, the debug line will display the raw PsPing output for diagnosis.
 
### VMware or VPN adapters flagged as "slow NIC"
**Cause:** Old recommendation logic matched `100 Mbps` anywhere in the adapter list, including virtual adapters.
**Status:** Fixed in v2.5. Virtual and VPN adapters are now excluded from the physical NIC speed check.
 
### Reports contain garbled characters (â€¢ â†')
**Cause:** Report was written as UTF-8 but viewed in Notepad or a tool expecting ASCII/Latin-1.
**Status:** Fixed in v2.5. Reports now use ASCII encoding and plain `*` / `->` characters.
 
### "Execution policy" errors
**Solution:** Use launcher Menu Option 3, or run:
`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`
 
### "Access denied" / Permission errors
**Solution:** Right-click `SystemTester.bat` and choose "Run as administrator".
 
### Sysinternals tools not found
**Solution:** Use launcher Menu Option 5 to auto-download, or manually download from [live.sysinternals.com](https://live.sysinternals.com).
 
### Reports not found after running tests
Reports are saved to a `Reports\` subfolder inside the script directory: not the script root itself.
 
Full path: `<script directory>\Reports\SystemTest_Clean_*.txt`
 
The `Reports\` folder is created automatically the first time a report is generated. If reports are missing:
- Confirm tests were run before generating the report (PS1 menu option 17, or use autorun)
- Check the script directory is not read-only (this can occur on some USB drives formatted as FAT32 with a write-protect switch)
- The console output after report generation always shows the exact file paths
### Tests taking too long: expected durations
- CPU Performance: ~10 seconds
- Power/Energy Report: ~15 seconds (admin only)
- Windows Update Search: 30-90 seconds
- DISM/SFC Scans: 5-15 minutes each (admin only)
- DirectX Diagnostics (dxdiag): up to 50 seconds
---
 
## Privacy and Safety
 
* **No Telemetry:** Script does not send data anywhere; purely local operation
* **Auto-Download:** Downloads only from official Microsoft servers (download.sysinternals.com)
* **Report Contents:** Includes computer name, hardware details, installed driver paths: review before sharing with clients
* **Admin Rights:** Required for DISM, SFC, energy reports, SMART data, Windows Update queries
* **SSL Bypass:** The certificate validation bypass used during speed/download tests is scoped per-request and restored immediately. It does not persist after the test completes.
---
 
## Version History
 
### v2.6: June 2026
- Rewrote network speed test engine: curl.exe (primary, WinHTTP/Schannel) → BITS → Invoke-WebRequest cascade for native TLS 1.3 on all systems
- Replaced retired `speed.hetzner.de` (DNS failure) with `speedtest.tele2.net/10MB.zip`
- Added PNWC branded ASCII startup banner with Clear-Host, version header, and system context
- Added `Invoke-GPUToolDownload` function: automated MSI Afterburner and FurMark downloads via curl.exe → BITS → IWR
- Batch: GPU Tools Manager Option 5 now triggers automated tool downloads directly
- Batch: Fixed GPU download parser errors caused by delayed expansion consuming `!` characters in inline PowerShell; moved all download logic to PS1 function, batch calls `-File` instead
- Fixed WHEA false positive: Level 4 informational events (including normal boot events) no longer trigger hardware error alert; filter now requires Level ≤ 3
- Fixed disk performance recommendations: split multiline `.*` regex into two separate match operations
- Fixed battery false positive on desktops: narrowed match from `"Battery"` to `"Battery: "`
- Fixed Wi-Fi NIC false positive: added `Wi-Fi|Wireless|WLAN` to adapter exclusion pattern
- Fixed SMART detection: added `"Unhealthy"` to `HealthStatus` pattern match
- Fixed Windows Update: consolidated duplicate check blocks; added branch for 1–5 pending updates
- Fixed clockres and du EULA output: added both to `-accepteula` injection list
- Fixed autorunsc producing usage text: corrected argument from `-a -c` to `-c` (default logon entries, CSV)
- Fixed PowerShell error formatting leaking into report output: added NativeCommandError/CategoryInfo filter to output cleaner
 
### v2.5: April 2026
- Fixed latency test crash: removed undefined `$targetPort` and broken `Test-NetConnection` args
- Fixed speed test SSL failure under VPN/proxy TLS interception
- Added 3-URL fallback chain for speed test (Cloudflare, Hetzner HTTP, OVH)
- Added per-attempt SSL bypass with automatic restore
- Fixed PsPing result parsing with flexible whitespace regex
- Added PsPing debug output when parsing fails
- Fixed false-positive "slow NIC" recommendation for virtual/VPN adapters
- Fixed report encoding mojibake: switched to ASCII, replaced Unicode bullets/arrows
- Removed Unicode box-drawing characters from menu display
- Reports now saved to `Reports\` subfolder instead of script root; folder is auto-created on first run
- Energy report (powercfg) also redirected into `Reports\` subfolder
- Batch: Added SSL bypass to Sysinternals Suite download
- Batch: Simplified VERIFY section, removed misleading exit-code branching
- Batch: Removed stale `SystemTester_FIXED.ps1` legacy filename reference
- Batch: Updated Help section to document v2.5 changes
- Batch: EXIT screen updated to show `Reports\` subfolder path
### v2.21: 2025
- Added tool integrity verification (digital signature checking)
- Added dual report system (Clean Summary + Detailed)
- Fixed memory usage calculation (FreePhysicalMemory unit conversion)
- Added launcher batch file with admin elevation
- Enhanced GPU testing: multi-GPU support, NVIDIA-SMI integration, AMD detection
- Added GPU Tools Manager (batch menu option 6)
- Added Windows Update integration
- Added WHEA hardware event log check
- Added network speed and latency testing (initial implementation)
### v2.0: 2024
- Complete rewrite with modular function structure
- Added interactive menu system
- Added `-AutoRun` parameter for unattended operation
- Added recommendations engine
- Improved report formatting
---
 
## Roadmap
 
### Near-term
- HTML report export with charts
- Baseline comparison mode (compare current vs. previous test)
- Skip flags (`-SkipCPU`, `-SkipNetwork`, etc.)
- CSV export for data analysis
- Memory leak detection
- Audio device testing
- Intel Arc GPU support
### Long-term
- WPF/WinUI graphical interface option
- Real-time monitoring dashboard
- Email report delivery
- Task Scheduler integration for scheduled testing
- Multi-computer report aggregation
- Signed releases with code signing certificate
- Pester test suite for CI/CD
---
 
## GPU Testing Details
 
### What Gets Tested
 
**Basic GPU Info (Option 12a):**
- All installed GPUs with full specs (VRAM, resolution, refresh rate, PNP ID)
- Display/monitor configuration with manufacturer and model decoding
- Driver details with digital signatures
- DirectX version and capabilities from dxdiag
- OpenGL registry information
- Hardware-accelerated GPU scheduling status
**Vendor-Specific Tests (Option 12b):**
- **NVIDIA:** Real-time metrics via nvidia-smi (temperature, utilization, memory, power draw, clock speeds)
- **AMD:** Registry-based driver detection across all registry positions (`\0000`, `\0001`, etc.)
**GPU Memory (Option 12c):**
- Total VRAM capacity
- Active GPU process detection via performance counters (falls back to basic info if unavailable)
### GPU Tool Requirements
 
| Tool | Required For | Status |
|------|--------------|--------|
| CIM/WMI | Basic GPU info | Always available |
| dxdiag | DirectX info | Always available |
| nvidia-smi | NVIDIA metrics | Included with NVIDIA drivers |
| Registry | AMD detection | Always available |
| GPU-Z | Advanced monitoring | Manual download via Option 6 |
 
### GPU Stress Testing (Optional)
 
Recommended tools via launcher Option 6 -> 4:
- **FurMark**: GPU stress test (generates significant heat: use with caution on laptops)
- **3DMark**: Industry standard benchmark
- **Unigine Heaven/Valley**: Graphics stress testing
- **OCCT**: Error detection and stability testing
---
 
## Contributing
 
Contributions welcome. Priority areas:
 
* **Bug reports**: test on varied hardware and network environments
* **Parsers**: new tool output cleaners for additional Sysinternals tools
* **Tests**: additional diagnostic modules (audio, temperatures, peripherals)
* **GPU**: Intel Arc integration
* **Network**: additional connectivity and performance tests
* **Documentation**: screenshots, wiki articles, tutorial content
**Before contributing:**
1. Open an issue to discuss large changes
2. Follow existing code style
3. Test on Windows 10 and Windows 11, admin and non-admin
4. Test on systems with VPN software active (Mullvad, Tailscale, WireGuard)
5. Update README and Help section in launcher
6. Run PSScriptAnalyzer if possible
**Testing Checklist:**
- [ ] Single GPU system (NVIDIA / AMD / Intel integrated)
- [ ] Multi-GPU system (discrete + integrated)
- [ ] System with active VPN (Mullvad, Tailscale, or similar)
- [ ] System with VMware or Hyper-V virtual adapters
- [ ] Paths with spaces in username
- [ ] Non-admin execution
- [ ] Admin execution
- [ ] Missing Sysinternals tools (should degrade gracefully)
- [ ] Menu Option 4 (Tool Verification)
- [ ] Menu Option 6 (GPU Tools Manager)
---
 
## License
 
MIT License: See [LICENSE](LICENSE) file for details.
 
**Copyright (c) 2025 Pacific Northwest Computers**
 
---
 
## Quick Links
 
* **Sysinternals Suite:** [live.sysinternals.com](https://live.sysinternals.com)
* **Sysinternals Docs:** [docs.microsoft.com/sysinternals](https://docs.microsoft.com/sysinternals)
* **PowerShell Docs:** [docs.microsoft.com/powershell](https://docs.microsoft.com/powershell)
* **GPU-Z:** [techpowerup.com/gpuz](https://www.techpowerup.com/gpuz/)
* **NVIDIA Drivers:** [nvidia.com/drivers](https://www.nvidia.com/Download/index.aspx)
* **AMD Drivers:** [amd.com/support](https://www.amd.com/en/support)
* **Issues:** [GitHub Issues](../../issues)
* **Discussions:** [GitHub Discussions](../../discussions)
---
 
## Support
 
* **Bug Reports:** Open a GitHub issue: include OS build, GPU type, admin status, and full error message
* **Feature Requests:** Start a GitHub discussion
* **Commercial Support:** jon@pnwcomputers.com / 360-624-7379
---
 
## Acknowledgments
 
* **Microsoft Sysinternals Team**: For the diagnostic tools this project is built around
* **Mark Russinovich**: For creating and maintaining Sysinternals
* **NVIDIA & AMD**: For providing diagnostic APIs
* **TechPowerUp**: For GPU-Z
* **PowerShell Community**: For patterns and best practices
---
 
*Tested on Windows 10 (1909+) and Windows 11: Enterprise, Pro, Home & Server editions*
 
**Last Updated:** June 2026 | **Version:** 2.6 | **Status:** Production Ready
