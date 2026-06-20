# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### 🔧 Fixed
- **Network Speed Test — TLS negotiation**: Enabled TLS 1.2/1.3 additively before each download attempt (with per-protocol fallback so it won't throw on older .NET runtimes) and restored the prior `SecurityProtocol` afterward. Prevents the HTTPS test URLs (e.g. Cloudflare) from failing silently on PowerShell 5.1 systems that default to TLS 1.0/1.1.
- **Network Speed Test — PowerShell 7+ cert bypass**: Added `-SkipCertificateCheck` on PowerShell 7+, where `Invoke-WebRequest` uses `HttpClient` and ignores the `ServicePointManager` certificate callback used to handle VPN/proxy TLS interception (Mullvad, Tailscale, etc.).
- **Network Speed Test — status reporting**: Reset `$status` to `SUCCESS` on a successful download so an earlier `Get-NetAdapter` failure no longer mislabels a working speed test as `FAILED`.
- **GPU VRAM detection — REG_BINARY crash**: `Get-AccurateVRAM` silently fell back to the capped 4 GB WMI value on driver versions that store `HardwareInformation.qwMemorySize` as `REG_BINARY` (byte array) instead of `REG_QWORD`. The direct `[int64]` cast would throw and be swallowed by the bare `catch {}`. Now detects the type and converts via `[System.BitConverter]::ToInt64()` when needed.
- **GPU memory — dangling cross-reference**: On multi-GPU systems where Windows performance counters are unavailable, per-adapter entries directed users to a "GPU-Memory-Total" section that was never created (its guard required both `$gpuCount -gt 1` AND `$countersAvailable`). The cross-reference message now only appears when the aggregate entry will actually be present in the report.
- **Disk performance — silent failure**: A disk test exception (e.g. `%TEMP%` write denied, out of disk space) printed a console warning but wrote nothing to `$TestResults`, so the failure was invisible in the saved report and excluded from the pass/fail summary counts. The catch block now records a `Status="FAILED"` entry.
- **OS Health — DISM runtime errors**: The v2.5.1 false-positive fix removed the `"error"` match term from the recommendations regex, inadvertently dropping coverage of `"DISM encountered an error"` — a real failure that was previously caught. Added `"DISM encountered|could not perform the requested operation"` to the positive match to restore this coverage.
- **OS Health — false-positive guard**: Added `"No integrity violations"` to the `-notmatch` exclusion list to prevent a false corruption warning from DISM `/CheckHealth` clean-system output, which uses different phrasing than `/ScanHealth`.
- **OS Health — non-English Windows**: DISM and SFC output is fully localized; on non-English Windows the English phrase matching silently produced a false-healthy report on corrupt systems. DISM's exit code (0 = clean, 11 = repairable corruption, other non-zero = error) is now captured and embedded in the stored output as a language-neutral signal used by the recommendations engine.
- **Windows Update — search failure**: A running-but-broken WU service (e.g. corrupted catalog, `StartType=Manual`) caused the search COM call to throw, writing "Search failed: ..." to the output but triggering no recommendation. Users saw a `SUCCESS` result with no guidance. A `WARNING` recommendation is now emitted when search failure is detected.
- **NVIDIA SMI — exit code ignored**: Both `nvidia-smi` invocations stored `Status="SUCCESS"` unconditionally regardless of the process exit code. GPU driver errors (e.g. driver not loaded, device unavailable) were silently recorded as passing. The exit code is now checked and mapped to `SUCCESS` or `FAILED` accordingly.

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
