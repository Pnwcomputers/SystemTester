# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- HTML report export with charts and graphs
- Baseline comparison mode (compare current vs. previous test run)
- Skip flags (`-SkipCPU`, `-SkipNetwork`, etc.) for targeted testing
- CSV export for data analysis
- Memory leak detection module
- Audio device testing
- Intel Arc GPU support
- Network deployment options / centralized log storage
- Multi-language support

---

## [2.6] - 2026-06-22

### 🚀 Added
- **PNWC Startup Banner**: Branded ASCII art header (`######  ##  ##  ##    ##  ######`) painted on launch with `Clear-Host` first to eliminate PowerShell startup noise. Shows version, contact, capability summary, timestamp, computer name, and drive. Pure 7-bit ASCII — no UTF-8 box characters that mangle on cp1252 console hosts.
- **`Invoke-GPUToolDownload` function**: New PS1 function handles automated download of MSI Afterburner and FurMark via curl.exe → BITS → IWR cascade with minimum file-size validation. Accepts `-DownloadGPUTool` and `-DownloadDir` script parameters so the batch launcher can invoke it cleanly via `-File` mode.
- **Batch: GPU Tools Manager Option 5 — Download GPU Tools Automatically**: Auto-downloads MSI Afterburner (MSI CDN) and FurMark (Geeks3D) directly to the `Tools\` folder without opening a browser. Old Option 5 (Return) moved to Option 6.

### 🔧 Fixed
- **Network Speed Test — full engine rewrite**: Replaced single-method `Invoke-WebRequest` approach with a three-method cascade: **curl.exe** (primary, WinHTTP/Schannel, native TLS 1.3) → **BITS** (fallback, also WinHTTP) → **Invoke-WebRequest** (last resort with TLS workarounds). Resolves systematic handshake failures on Cloudflare and OVH under Mullvad VPN and similar environments where `.NET ServicePointManager` bypass fires too late in the TLS stack.
- **Network Speed Test — dead URL**: Replaced `speed.hetzner.de` (hostname retired, DNS failure on all systems) with `speedtest.tele2.net/10MB.zip` in the HTTP fallback slot.
- **Network Speed Test — TLS negotiation**: Enabled TLS 1.2/1.3 additively before each IWR attempt with per-protocol fallback, restored afterward. Prevents silent failures on PowerShell 5.1 systems that default to TLS 1.0/1.1.
- **Network Speed Test — PowerShell 7+ cert bypass**: Added `-SkipCertificateCheck` for PowerShell 7+ where `Invoke-WebRequest` uses `HttpClient` and ignores `ServicePointManager` callbacks.
- **Network Speed Test — status reporting**: Reset `$status` to `SUCCESS` on a successful download so an earlier `Get-NetAdapter` failure no longer mislabels a working speed test as `FAILED`.
- **Batch Launcher — GPU download parser errors**: `setlocal enabledelayedexpansion` caused `!` characters in inline PowerShell strings (e.g. `heat!`) to be consumed by cmd.exe before PowerShell received the script, producing `Missing closing '}'`, `The Try statement is missing its Catch or Finally block`, and `Unexpected token ')'`. Fixed by moving all download logic into `Invoke-GPUToolDownload` in the PS1; batch now calls `-File "%SCRIPT_PS1%" -DownloadGPUTool "..." -DownloadDir "..."`.
- **WHEA false positive**: Level 4 informational events from `Microsoft-Windows-WHEA-Logger` — including "WHEA has started" (Event ID 1) which fires on every Windows boot — triggered "Hardware errors detected" on all healthy systems. Added `Where-Object { $_.Level -le 3 }` to restrict to Warning/Error/Critical only.
- **Disk performance — silent regex failure**: `"Write: ([\d\.]+) MB/s.*Read: ([\d\.]+) MB/s"` used `.*` which cannot cross newlines in PowerShell `-match`. Write and Read speeds are stored on separate output lines, so the regex never matched on any system and disk performance recommendations never fired. Split into two independent `if (-match)` blocks.
- **Battery false positive on desktops**: `$powerInfo.Output -match "Battery"` matched the string `"No battery (desktop)"` emitted by desktop systems. Changed to `"Battery: "` (colon + space) which only matches actual battery data lines.
- **Wi-Fi NIC false positive**: 802.11n adapters at 100 Mbps incorrectly triggered "Physical network adapter running at 10/100 Mbps — Upgrade to Gigabit Ethernet." Added `Wi-Fi|Wireless|WLAN` to the adapter line exclusion pattern.
- **SMART detection — missing status**: `"Unhealthy"` `HealthStatus` from `Get-PhysicalDisk` was absent from the recommendations pattern match. Added alongside `Warning|Caution|Failed|Degraded`.
- **Windows Update — duplicate recommendations**: Two separate check blocks both fired `"ACTION: N Windows update(s)"` for any `pendingCount > 0`. Removed the early duplicate block; all Windows Update recommendations consolidated into a single block.
- **Windows Update — 1–5 pending gap**: Removing the early duplicate left systems with 1–5 pending updates producing no recommendation. Added `elseif ($pendingCount -gt 0)` branch to the consolidated block covering the full range: `>20` WARNING, `>5` INFO, `>0` ACTION, `0` GOOD.
- **GPU VRAM detection — REG_BINARY crash**: `Get-AccurateVRAM` silently fell back to the WMI 4 GB cap when `HardwareInformation.qwMemorySize` was stored as `REG_BINARY` (byte array) instead of `REG_QWORD`. Direct `[int64]` cast threw and was swallowed by bare `catch {}`. Now detects the registry type and converts via `[System.BitConverter]::ToInt64()`.
- **GPU memory — dangling cross-reference**: On multi-GPU systems without available performance counters, per-adapter entries pointed to a "GPU-Memory-Total" aggregate section that was never written (its guard required both `$gpuCount -gt 1` AND `$countersAvailable`). Cross-reference now only appears when the aggregate section will actually be present.
- **Disk performance — exception not recorded**: A disk test exception (`%TEMP%` write denied, out of disk space, etc.) printed a console warning but wrote nothing to `$TestResults`, making the failure invisible in the report and excluded from pass/fail counts. Catch block now records `Status="FAILED"`.
- **OS Health — DISM error coverage restored**: A prior false-positive fix removed `"error"` from the recommendations regex, inadvertently dropping `"DISM encountered an error"`. Restored via `"DISM encountered|could not perform the requested operation"`.
- **OS Health — false-positive guard**: Added `"No integrity violations"` to the `-notmatch` exclusion list to prevent false corruption warning from DISM `/CheckHealth` output on clean systems.
- **OS Health — non-English Windows**: DISM and SFC output is localized; English phrase matching silently produced false-healthy results on non-English corrupt systems. DISM exit code (0 = clean, 11 = repairable, other = error) now captured and embedded as a language-neutral signal.
- **Windows Update — search failure unhandled**: A running-but-broken WU service caused the COM search call to throw, writing "Search failed: ..." to output but triggering no recommendation. A WARNING recommendation is now emitted when search failure is detected.
- **NVIDIA SMI — exit code ignored**: Both `nvidia-smi` invocations stored `Status="SUCCESS"` unconditionally. GPU driver errors (driver not loaded, device unavailable) were silently recorded as passing. Exit code is now checked and mapped correctly.
- **Tool output — clockres and du EULA**: Neither `clockres` nor `du` were in the `-accepteula` injection list. On systems without prior EULA acceptance cached in the registry, both tools wrote the full Sysinternals license text into their report sections instead of actual data. Added to the list alongside `psinfo`, `pslist`, `handle`, `autorunsc`.
- **Tool output — autorunsc usage help instead of entries**: `autorunsc -a -c` caused autorunsc's parser to consume `-c` as the selection type argument for `-a` (character `c` = Codecs only), leaving no CSV flag — tool printed usage/help instead of autorun entries. Changed to `-c` only; default behavior is logon startup entries in CSV format.
- **Tool output — NativeCommandError formatting in reports**: `2>&1` in `Invoke-Tool` causes PowerShell 5.1 to wrap native-process stderr lines as `NativeCommandError` objects. `Out-String` serializes these as multi-line blocks containing `CategoryInfo`, `FullyQualifiedErrorId`, and `At <path>:line` context. `Convert-ToolOutput` now skips lines matching these patterns.

### 📈 Changed
- GPU Tools Manager sub-menu renumbered: old Option 5 (Return to Main Menu) is now Option 6; new Option 5 is Download GPU Tools Automatically.
- Startup banner replaces simple 4-line version header; `Clear-Host` precedes the banner to eliminate PowerShell startup noise.

---

## [2.5] - 2026-05-01

### 🚀 Added
- **TLS 1.3 Support**: Rewrote download engine to support modern TLS 1.3/1.2 protocols via bitwise OR mask, preventing "Connection Closed" errors on Microsoft CDNs.
- **Enhanced GPU Reporting**: Implemented registry-level VRAM detection to bypass the 4GB WMI truncation bug; now accurately reports high-end cards (e.g., RTX 5070 12GB).
- **Multi-GPU Intelligence**: Added system-wide GPU memory aggregation for machines with both iGPU and discrete graphics.
- **Expanded NIC Filtering**: Added ZeroTier, AnyConnect, GlobalProtect, Fortinet, and more to the virtual adapter exclusion list.

### 🔧 Fixed
- **Launcher Awareness**: Fixed a critical bug where the script failed to detect the .bat launcher on PowerShell 5.1.
- **Network Speed Logic**: Switched Mbps calculations to base-10 to match ISP reporting and added a 1MB sanity floor to prevent false "slow internet" warnings from error pages.
- **Storage Diagnostics**: Rewrote disk performance tests to use `WriteThrough` flags, ensuring real disk throughput is measured rather than system cache.
- **Recommendation Engine**: Refined regex logic to eliminate false positives for "System Corruption" and "Windows Update Stopped" (now checks StartType).
- **Security**: Implemented `try/finally` blocks to ensure system SSL certificate callbacks are always restored to default state after testing.

### 📈 Changed
- Updated Sysinternals Suite size estimate to ~170MB.
- Increased download timeout to 180s to accommodate larger payloads on slower links.
- "EXCELLENT" status now only triggers if zero warnings/critical issues are found by the engine.

---

## [2.4.0] - 2026-04-23

### Fixed

**Network — Latency Test**
- `$targetPort` was never defined, causing `Test-NetConnection` to receive `Port=0` and throw a
  validation error on every run — latency test now correctly runs as ICMP-only with no port argument
- `Test-NetConnection -InformationLevel Detailed` removed; it requires a valid port and is
  unnecessary for basic ping latency measurement
- `PsPing` was called with `IP:Port` format instead of bare IP for ICMP mode
- `PsPing` result regex was too strict — minor whitespace variations in output caused results to be
  silently dropped; regex now uses flexible `\s*` matching
- Added debug output line showing raw PsPing tail when parsing still fails, making future
  diagnosis possible without re-running the test

**Network — Speed Test**
- Single hardcoded Hetzner HTTPS URL failed under VPN/proxy TLS interception (Mullvad, Tailscale,
  corporate proxies) with no fallback — replaced with a 3-URL chain: Cloudflare, Hetzner HTTP, OVH
- Added per-attempt SSL certificate validation bypass to handle MITM interception; bypass is
  scoped to the request and restored immediately after each attempt regardless of success or failure
- Added minimum file size check (1000 bytes) to prevent a firewall error page from being recorded
  as a successful download result

**Network — Recommendations**
- Virtual and VPN adapters (VMware VMnet, Hyper-V vEthernet, Tailscale, Mullvad, WireGuard,
  TAP-Windows, OpenVPN) were incorrectly flagged as "slow physical NICs" at 100 Mbps
- Recommendation engine now iterates adapter lines individually and excludes known virtual/VPN
  adapter name patterns before applying the slow-speed check

**Reports — Output Location**
- Reports were saving to the script root directory; now saved to a `Reports\` subfolder
- `Reports\` folder is created automatically on first report generation
- Energy report (`powercfg /energy`) redirected into `Reports\` alongside text reports
- Write-access test updated to target `Reports\` folder; error messages now include the specific
  path that failed

**Reports — Encoding**
- Report files written as UTF-8 caused Unicode bullets (`•`) and arrows (`→`) to render as
  mojibake (`â€¢ â†'`) in Notepad and legacy text viewers
- Switched `Out-File` encoding from UTF8 to ASCII throughout report generation
- Replaced all Unicode bullet (`•`) characters with `*` and arrow (`→`) characters with `->`
- Removed Unicode box-drawing characters (`└─`) from PowerShell menu display strings
- Script file is now fully 7-bit ASCII — no encoding surprises in any editor or viewer

**Batch Launcher**
- Sysinternals Suite auto-download used a single HTTPS URL with no SSL bypass — same VPN/proxy
  TLS interception issue as the PS1 speed test; same fix applied
- `VERIFY` section exit-code branching silently swallowed function output, producing misleading
  success messages regardless of actual result; simplified to direct output display
- Stale reference to legacy `SystemTester_FIXED.ps1` filename removed from error message
- EXIT screen updated to show correct `Reports\` subfolder path

---

## [2.21.0] - 2025-09-02

### Added
- Tool integrity verification with digital signature checking for all Sysinternals executables
- Dual report system: timestamped Clean Summary and Detailed output saved as separate `.txt` files
- Batch launcher (`SystemTester.bat`) with reliable admin elevation and interactive menu
- GPU Tools Manager — batch menu option 6 for managing NVIDIA, AMD, and GPU-Z testing utilities
- Enhanced GPU testing: multi-GPU support, NVIDIA-SMI integration, AMD driver detection via registry
- DirectX diagnostics via `dxdiag`, OpenGL registry check, hardware-accelerated GPU scheduling detection
- Windows Update integration — checks pending updates, lists titles and classifications, reports service status
- WHEA hardware event log scan covering last 7 days
- Network speed and latency testing (initial implementation: `Test-NetConnection`, `PsPing`)
- Launcher awareness detection — script detects if launched via batch file for context-aware messages
- `Test-OSHealth` — runs DISM `/ScanHealth` and SFC for OS integrity (admin only)
- `Test-StorageSMART` — collects health status and media type from physical disks
- `Test-Trim` — checks SSD TRIM enablement status via `fsutil`
- `Test-NIC` — captures active network adapter details including link speed and MAC address
- `Test-GPU` — GPU and display configuration with DirectX and OpenGL information
- `Test-Power` — battery status and `powercfg /energy` report generation (admin only)
- `Test-HardwareEvents` — WHEA error log scan
- Support for additional Sysinternals tools: `sigcheck`, `contig`, `diskext`, `listdlls`, `clockres`
- `-AutoRun` parameter for unattended full-suite execution with automatic report generation
- Color-coded console output (green/yellow/red) for all test results and recommendations
- Recommendations engine — dynamically generated findings covering memory, CPU, disk, SMART,
  TRIM, network, GPU drivers, Windows Update, and WHEA events
- GPU sub-menu options: `12a` (basic info), `12b` (vendor-specific), `12c` (GPU memory)
- GPU-Z download assistant with file size validation in batch launcher

### Fixed
- Memory usage calculation: `FreePhysicalMemory` (reported in KB) was not being converted
  correctly, causing inflated usage percentages

### Changed
- Admin elevation method replaced: `net session` check swapped for PowerShell
  `WindowsPrincipal.IsInRole` with `FLTMC` as fallback — more reliable on systems where the
  Server service is disabled
- Interactive menu expanded to 18 options
- Report executive summary now includes total tests, success/failure counts, success rate, and duration
- Detailed report output cleaned and limited to first 40 lines per tool to reduce file size

---

## [2.0.0] - 2024-11-01

### Added
- Complete rewrite with modular function structure
- Interactive menu system with numbered options
- Recommendations engine (initial version)
- Improved report formatting with section headers

### Changed
- Monolithic script refactored into discrete test functions
- All WMI calls migrated to CIM instances for better performance and PowerShell 7 compatibility

---

## [1.0.0] - 2024-01-01

### Added
- Initial release
- Core Sysinternals tool runner: `psinfo`, `coreinfo`, `pslist`, `handle`, `clockres`, `autorunsc`, `du`
- Basic system information collection (OS, CPU, RAM, storage)
- Single text report output
- Manual Sysinternals installation required
