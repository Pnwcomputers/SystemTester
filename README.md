# 🧰 Portable Sysinternals System Tester v2.21

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

## 🚀 NOW With Enhanced GPU Testing, Advanced Network Suite & Critical Bug Fixes

Version 2.21 introduces comprehensive GPU testing capabilities, advanced network speed/latency testing, and fixes several critical bugs that prevented the script from running properly.

### Key New Capabilities:

* 🖱️ **One-click Menu or Autorun** — interactive menu or `-AutoRun` parameter
* 🧹 **Output Cleaner** — removes banners, EULA text, usage blocks for readable reports
* 🧠 **Comprehensive Tests** — CPU, RAM, Disk, GPU, Network, OS Health, Windows Update status
* 🎮 **Enhanced GPU Testing** — Multi-GPU support, NVIDIA/AMD vendor tools, display configuration
* 🌐 **Advanced Network Speed Suite** — Complete connectivity, latency, DNS, MTU, and bandwidth testing
* 📝 **Enhanced Network Testing** — Link status, speed, IP/MAC addresses, PSPing integration
* 🔧 **Tool Integrity Verification** — Digital signature checking for Sysinternals tools
* 🗂️ **Smart Reporting** — timestamped **Summary** + **Detailed** TXT reports with actionable recommendations
* 📦 **Fully Portable** — run from USB; no installation required
* 🧰 **Graceful Degradation** — missing tools detected and skipped automatically with helpful messages
* 🔐 **Robust Elevation Handling** — reliable admin detection (Windows Home compatible)
* 📥 **Auto-Download Tools** — built-in Sysinternals Suite downloader (no manual setup needed!)
* 🔄 **Windows Update Integration** — checks pending updates, history, and service status
* ⚡ **Modern PowerShell** — uses CIM instances (not deprecated WMI) for better performance

---

## 🐛 Critical Bug Fixes in v2.21

### PowerShell Script Fixes

| Issue | Impact | Status |
|-------|--------|--------|
| **Missing `Initialize-Environment` function** | 🔴 **CRITICAL** - Script crashed on startup | ✅ Fixed |
| **Broken `Test-ToolIntegrity` function** | 🔴 Tool verification failed | ✅ Fixed |
| **Missing `Test-ToolVerification` function** | 🟡 Batch menu option 4 crashed | ✅ Fixed |
| **Wrong DISM/SFC code in SMART test** | 🟡 SMART test ran wrong operations | ✅ Fixed |
| **Incorrect TRIM output message** | 🟢 Cosmetic only | ✅ Fixed |
| **AMD GPU detection limited to registry \0000** | 🟡 Multi-GPU AMD systems not detected | ✅ Fixed |
| **GPU driver year parsing could crash** | 🟢 Rare crash in recommendations | ✅ Fixed |
| **COM object memory leak in Windows Update** | 🟢 Minor memory leak | ✅ Fixed |

### Batch Launcher Fixes

| Issue | Impact | Status |
|-------|--------|--------|
| **Duplicate Sysinternals folder check** | 🟢 Annoying duplicate warnings | ✅ Fixed |
| **AMD GPU detection limited to \0000** | 🟡 Multi-GPU AMD systems not detected | ✅ Fixed |
| **No GPU-Z size validation** | 🟢 Corrupted files not caught | ✅ Fixed |
| **Inconsistent errorlevel checking** | 🟢 Minor reliability issues | ✅ Fixed |

### Impact Summary

**Before Fixes:**
- ❌ PowerShell script would crash immediately on startup
- ❌ Tool verification from batch menu would fail
- ⚠️ AMD GPUs only detected if in first registry position
- ⚠️ SMART test would incorrectly run DISM/SFC scans

**After Fixes:**
- ✅ Script runs reliably from startup
- ✅ All menu options functional
- ✅ Multi-GPU systems fully supported
- ✅ All tests run correct operations
- ✅ Better error handling throughout

---

## 🧩 Requirements

* **OS:** Windows 10/11 (Windows Server supported)
* **PowerShell:** 5.1+ or PowerShell 7
* **Permissions:** Administrator rights recommended (some tests require elevation)
* **Internet:** Only needed for auto-download feature (optional)
* **Sysinternals Tools:** Auto-downloadable via launcher or manual installation
* **GPU Tools (Optional):** NVIDIA drivers (nvidia-smi), AMD drivers, GPU-Z

---

## 📁 Recommended Folder Structure

```
📂 SystemTester/
├── 📄 SystemTester.ps1    # Main PowerShell script (USE THIS)
├── 📄 SystemTester.bat    # Batch launcher (USE THIS)
├── 📄 README.md                 # This file
├── 📄 LICENSE                   # MIT License
├── 📂 Sysinternals/             # Auto-created by launcher
│   ├── psinfo.exe
│   ├── coreinfo.exe
│   ├── pslist.exe
│   ├── handle.exe
│   ├── autorunsc.exe
│   ├── psping.exe              # For advanced network latency testing
│   └── ... (60+ other tools)
├── 📂 Tools/                    # GPU testing tools (optional)
│   └── GPU-Z.exe               # Downloaded via Option 6
└── 📂 Reports/                  # Created when tests run
    ├── SystemTest_Clean_20250103_143022.txt
    └── SystemTest_Detailed_20250103_143022.txt
```

---

## 🚀 Quick Start

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

> ℹ️ **Launcher compatibility:** The batch launcher automatically detects either `SystemTester_FIXED.ps1` or the legacy `SystemTester.ps1` filename, so both naming conventions continue to work.

### **First-Time Setup**

If Sysinternals tools are missing:
1. **Automatic:** Use launcher Menu Option 5 to download (~35 MB)
2. **Manual:** Download from [live.sysinternals.com](https://live.sysinternals.com), extract to `.\Sysinternals\`

For enhanced GPU testing:
1. **NVIDIA GPUs:** Install latest NVIDIA drivers (includes nvidia-smi)
2. **AMD GPUs:** Install latest AMD drivers
3. **GPU-Z (Optional):** Use launcher Menu Option 6 → 1 to download

---

## 🧪 Test Suites (18 Categories)

| # | Category | Description | Key Tools Used |
|---|----------|-------------|----------------|
| 1 | **System Information** | OS details, computer info, clock resolution | `psinfo`, `clockres`, CIM queries |
| 2 | **CPU Testing** | Architecture, performance benchmarks, top processes | `coreinfo`, stress test, process analysis |
| 3 | **RAM Testing** | Memory capacity, modules, usage patterns | CIM queries, `testlimit`, performance counters |
| 4 | **Storage Testing** | Drives, fragmentation, performance, SMART data | `du`, `contig`, `streams`, read/write tests |
| 5 | **Process Analysis** | Running processes, handles, process tree | `pslist`, `handle` |
| 6 | **Security Analysis** | Autorun entries, startup items | `autorunsc` |
| 7 | **Network Analysis** | Connectivity, latency, DNS, bandwidth, MTU | `netstat`, `Get-NetAdapter`, `psping`, `Test-NetConnection` |
| 8 | **OS Health** | System file integrity, component store | `DISM`, `SFC` |
| 9 | **Storage SMART** | Drive health, reliability counters | `Get-PhysicalDisk`, WMI SMART |
| 10 | **SSD TRIM** | TRIM enablement status | `fsutil` |
| 11 | **Network Adapters** | Link status, speed, IP/MAC addresses | `Get-NetAdapter`, `Get-NetIPConfiguration` |
| 12 | **GPU (Enhanced)** | Multi-GPU info, vendor tools, memory | CIM, `dxdiag`, `nvidia-smi`, GPU-Z |
| 12a | **Basic GPU Info** | Details, displays, drivers, DirectX, OpenGL | CIM queries, `dxdiag` |
| 12b | **Vendor-Specific** | NVIDIA/AMD metrics, temperatures, utilization | `nvidia-smi`, AMD registry |
| 12c | **GPU Memory** | VRAM capacity, usage, performance counters | CIM, performance counters |
| 13 | **Power/Battery** | Battery health, energy report | `powercfg`, WMI Battery |
| 14 | **Hardware Events** | WHEA error logs (last 7 days) | Event Viewer (WHEA-Logger) |
| 15 | **Windows Update** | Pending updates, history, service status | Windows Update COM API |

### Network Speed Test Suite (Option 7) Features:

* **Local Connectivity** — Tests local network and default gateway reachability (`Test-NetConnection`)
* **Internet Reachability** — Connectivity tests to multiple endpoints (Google DNS, Cloudflare DNS, Google.com, Microsoft.com) with port-specific testing (DNS 53, HTTPS 443)
* **Latency Testing** — Detailed ping tests to multiple targets with round-trip time measurements
* **PSPing Integration** — Advanced latency and TCP bandwidth capacity testing for connection quality analysis (requires `psping.exe` in Sysinternals folder)
* **DNS Resolution Speed** — Measures DNS lookup speed for multiple domains in milliseconds
* **Network MTU Discovery** — Checks for standard MTU (1500 bytes) without fragmentation to help identify network configuration issues

---

## 📊 Sample Output

### Clean Summary Report
```
=========================================
  SYSTEM TEST REPORT v2.21
  CLEAN SUMMARY
=========================================
Date: 2025-01-03 14:30:22
Computer: DESKTOP-ABC123
Admin: YES

SUMMARY:
  Total Tests: 32
  Success: 30
  Failed: 0
  Skipped: 2
  Success Rate: 93.8%

KEY FINDINGS:
-------------

SYSTEM:
  OS: Microsoft Windows 11 Pro 10.0.22631
  Architecture: 64-bit
  Computer: DESKTOP-ABC123
  Manufacturer: Dell Inc.
  Model: XPS 15 9520
  RAM: 32 GB
  
MEMORY:
  Total RAM: 32 GB
  Available: 18.5 GB
  Used: 13.5 GB
  Usage: 42.2%
  
DISK PERFORMANCE:
  Write: 487.3 MB/s
  Read: 523.1 MB/s

GPU:
  Name: NVIDIA GeForce RTX 3060
  Adapter RAM: 12 GB
  Driver Version: 31.0.15.4601

RECOMMENDATIONS:
----------------
• GOOD: Low memory usage (42.2%) - plenty of RAM available
• INFO: GPU drivers are over 1 year old (2023)
  → Update to latest drivers for best performance
  → NVIDIA: GeForce Experience or nvidia.com
  → AMD: amd.com/en/support
• WARNING: 15 pending Windows Updates
  → Install updates soon for security and stability
  → Schedule during non-working hours
• EXCELLENT: All tests passed successfully
  → System is operating normally

For detailed output, see: SystemTest_Detailed_20250103_143022.txt
```

---

## 🔧 Launcher Menu Options

The batch launcher (`SystemTester.bat`) provides:

1. **Run Interactive Menu** — Select individual tests (includes GPU sub-options)
2. **Run ALL Tests Automatically** — Complete system scan with auto-report
3. **Fix PowerShell Execution Policy** — Set CurrentUser to RemoteSigned
4. **Verify Tool Integrity** — Check digital signatures and file sizes (FIXED: now works!)
5. **Download/Update Sysinternals Suite** — Auto-download from Microsoft (~35 MB)
6. **GPU Testing Tools Manager** — Download and manage GPU testing tools
   - GPU-Z installation assistant (with size validation)
   - NVIDIA tools verification (nvidia-smi)
   - AMD driver detection (multi-GPU support)
   - Tool recommendations (FurMark, 3DMark, etc.)
7. **Help / Troubleshooting** — Comprehensive troubleshooting guide
8. **Exit** — Close launcher

### GPU Testing Sub-Menu (PowerShell Option 12)

When you select GPU testing in the PowerShell menu, you can:
* **12** - Run all GPU tests (comprehensive)
* **12a** - Basic GPU info only (fastest, ~3-5 seconds)
* **12b** - Vendor-specific tools (NVIDIA-SMI, AMD - now detects all GPUs)
* **12c** - GPU memory testing

---

## 🛠️ Troubleshooting

### "Sysinternals tools not found"
**Solution:** Use launcher Menu Option 5 to auto-download, or manually download from [live.sysinternals.com](https://live.sysinternals.com)

### "Execution policy" errors
**Solution:** Use launcher Menu Option 3, or run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`

### "Access denied" / Permission errors
**Solution:** Right-click launcher and choose "Run as administrator"

### Script crashes immediately on startup (v2.21 original only)
**Solution:** ✅ **FIXED** - Use `SystemTester.ps1` instead. Original had missing `Initialize-Environment` function.

### Tool verification (Menu Option 4) crashes
**Solution:** ✅ **FIXED** - Use `SystemTester.bat` and `SystemTester.ps1`. Missing function has been added.

### AMD GPU not detected (multi-GPU systems)
**Solution:** ✅ **FIXED** - Script now checks ALL registry subkeys (\0000, \0001, \0002, etc.), not just \0000.

### GPU-Z appears corrupted
**Solution:** ✅ **FIXED** - Launcher now validates file size (should be >1MB). Re-download if size is too small.

### SMART test runs DISM/SFC instead
**Solution:** ✅ **FIXED** - Incorrect code has been removed from SMART test function.

### Windows Update check fails
**Solution:** Ensure Windows Update service is running; may require administrator rights

### GPU tests show "SKIPPED"
**Solution:** 
- For NVIDIA: Install latest drivers from nvidia.com
- For AMD: Install latest drivers from amd.com/support
- nvidia-smi is included with NVIDIA drivers
- Some GPU tests don't require special tools and should always work
- **Note:** AMD detection now properly checks all registry locations

### Tests taking too long
**Expected:** Some tests are intentionally slow:
- CPU Performance: 10-30 seconds
- Power/Energy Report: 15-20 seconds (admin only)
- Windows Update Search: 30-90 seconds
- DISM/SFC Scans: 5-15 minutes each (admin only)
- DirectX Diagnostics (dxdiag): Up to 50 seconds

---

## 🛡️ Privacy & Safety

* **Admin Rights:** Required for DISM, SFC, energy reports, SMART data, Windows Update queries
* **Report Contents:** Includes computer name, username, installed software paths, hardware details
* **Data Sensitivity:** Reports may reveal system configuration—review before sharing
* **No Telemetry:** Script does not send data anywhere; purely local operation
* **Auto-Download:** Only downloads from official Microsoft servers (download.sysinternals.com)
* **GPU Tools:** GPU-Z must be downloaded manually from techpowerup.com (launcher opens browser)
* **File Validation:** Tool integrity verification checks digital signatures and file sizes

---

## 📋 What's New in Version 2.21

### Major New Features

| Feature | Description |
| :--- | :--- |
| **Advanced Network Speed Suite** | Complete connectivity, latency, DNS resolution, PSPing bandwidth, and MTU testing |
| **Tool Integrity Verification** | Check digital signatures and validate file sizes of Sysinternals tools |
| **Enhanced GPU Testing** | Multi-GPU support, vendor-specific tools (NVIDIA/AMD), display configuration |
| **GPU Tools Manager** | New batch menu option for managing GPU testing utilities |
| **Dual Report System** | Clean summary + detailed output in separate timestamped files |
| **Launcher Awareness** | Script detects if launched via batch file for better guidance |

### Critical Bug Fixes

| Fix | Description |
| :--- | :--- |
| **Initialize-Environment** | Added missing function - script now starts properly |
| **Tool Verification** | Fixed broken integrity checking - Menu Option 4 now works |
| **AMD Multi-GPU** | Now detects AMD GPUs in any registry position, not just \0000 |
| **SMART Test** | Removed incorrect DISM/SFC code - runs proper SMART checks |
| **GPU-Z Validation** | Added size checking to detect corrupted downloads |
| **COM Cleanup** | Improved memory management in Windows Update test |
| **TRIM Message** | Fixed incorrect output message (was "SMART data collected") |
| **Driver Year Parsing** | Added error handling to prevent crashes in recommendations |
| **Duplicate Checks** | Removed redundant Sysinternals folder validation |
| **ErrorLevel Consistency** | Standardized error checking in batch file |

### Improvements

* Better error messages throughout
* More robust path handling for spaces in usernames
* Enhanced recommendations engine with more actionable advice
* Improved GPU driver age detection with fallback handling
* Better COM object lifecycle management
* Network testing now includes comprehensive connectivity analysis
* PSPing integration for advanced latency and bandwidth testing

---

## 🗺️ Roadmap

### Version 2.3
* HTML report export with charts and graphs
* Baseline comparison mode (compare current vs. previous tests)
* Skip flags (`-SkipCPU`, `-SkipNetwork`, etc.)
* CSV export for data analysis
* Enhanced network throughput testing (extended PSPing integration)
* Memory leak detection
* Audio device testing
* Intel Arc GPU support

### Version 3.0 (Long-term)
* WPF/WinUI graphical interface option
* Pluggable module system for custom tests
* Real-time monitoring dashboard
* Email report functionality
* Task Scheduler integration for automated testing
* Multi-computer report aggregation
* Signed releases with code signing certificate
* Pester test suite for CI/CD
* Docker container for testing (Windows containers)

---

## 🎮 GPU Testing Details

### What Gets Tested

**Basic GPU Info (Option 12a):**
- All installed GPUs with detailed specs
- Display/monitor configuration
- Driver details with digital signatures
- DirectX version and capabilities
- OpenGL registry information
- Hardware-accelerated GPU scheduling status

**Vendor-Specific Tests (Option 12b):**
- **NVIDIA:** Real-time metrics via nvidia-smi
  - Temperature, utilization, memory usage
  - Power draw, clock speeds
  - Full detailed GPU query
- **AMD:** Registry-based driver detection (✅ FIXED: Multi-GPU support)
  - Driver version and date
  - GPU identification
  - Detects GPUs in any registry position

**GPU Memory (Option 12c):**
- Total VRAM capacity
- Active GPU process detection
- Performance counter integration

### GPU Tool Requirements

| Tool | Required For | Included With | Status |
|------|--------------|---------------|--------|
| CIM/WMI | Basic info | Windows (always available) | ✅ Always works |
| dxdiag | DirectX info | Windows (always available) | ✅ Always works |
| nvidia-smi | NVIDIA metrics | NVIDIA drivers | Optional |
| Registry | AMD detection | Windows (always available) | ✅ Fixed for multi-GPU |
| GPU-Z | Advanced monitoring | Manual download (optional) | ✅ Size validated |

### GPU Stress Testing (Optional)

The launcher's GPU Tools Manager (Option 6) provides recommendations for:
- **FurMark** - GPU stress test (generates significant heat!)
- **3DMark** - Industry standard benchmarking
- **Unigine Heaven/Valley** - Graphics stress testing
- **OCCT** - Error detection and stability testing

**⚠️ Warning:** Stress tests generate significant heat and should be used with caution on laptops.

---

## 🤝 Contributing

Contributions welcome! Areas of interest:

* **Bug Reports:** Test the fixed version and report any remaining issues
* **Parsers:** New tool output cleaners
* **Tests:** Additional diagnostic modules (audio, peripherals, temperatures)
* **GPU Tools:** Additional vendor integrations (Intel Arc, etc.)
* **Network Tools:** Additional connectivity and performance tests
* **Performance:** Optimization of slow operations
* **Documentation:** Tutorial videos, screenshots, wiki articles
* **Testing:** Pester unit tests, integration tests
* **Internationalization:** Multi-language support

**Before contributing:**
1. Open an issue to discuss large changes
2. Follow existing code style and patterns
3. Test on Windows 10 and Windows 11
4. Test with multiple GPU types if possible (NVIDIA, AMD, integrated)
5. Test on multi-GPU systems if available
6. Update README and help text
7. Run PSScriptAnalyzer if possible

**Testing Checklist:**
- [ ] Single GPU system (NVIDIA/AMD/Intel)
- [ ] Multi-GPU system (if available)
- [ ] Paths with spaces in username
- [ ] Non-admin execution
- [ ] Admin execution
- [ ] Missing Sysinternals tools
- [ ] Menu Option 4 (Tool Verification)
- [ ] Menu Option 6 (GPU Tools Manager)
- [ ] Network connectivity tests (various network conditions)

---

## 📜 License

MIT License - See [LICENSE](LICENSE) file for details

**Copyright (c) 2025 Pacific Northwest Computers**

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

---

## 🔗 Quick Links

* **Download Sysinternals:** [live.sysinternals.com](https://live.sysinternals.com)
* **Sysinternals Documentation:** [docs.microsoft.com/sysinternals](https://docs.microsoft.com/sysinternals)
* **PowerShell Documentation:** [docs.microsoft.com/powershell](https://docs.microsoft.com/powershell)
* **GPU-Z Download:** [techpowerup.com/gpuz](https://www.techpowerup.com/gpuz/)
* **NVIDIA Drivers:** [nvidia.com/drivers](https://www.nvidia.com/Download/index.aspx)
* **AMD Drivers:** [amd.com/support](https://www.amd.com/en/support)
* **Report Issues:** [GitHub Issues](../../issues)
* **Feature Requests:** [GitHub Discussions](../../discussions)

---

## 🔒 Security

For security vulnerabilities or sensitive findings:
* **Email:** support@pnwcomputers.com
* **Response Time:** Within 48 hours for critical issues
* **Disclosure:** Responsible disclosure appreciated (30-90 day window)

**Please include:**
* Detailed reproduction steps
* Affected versions (specify if original v2.21 or FIXED version)
* Potential impact assessment
* Suggested remediation (if any)

---

## 📞 Support

* **Documentation Issues:** Open a GitHub issue
* **Feature Requests:** Start a GitHub discussion
* **Bug Reports:** Open a GitHub issue (specify which version you're using)
* **General Questions:** Check the Help section in launcher (Option 7)
* **GPU Testing Help:** See GPU Tools Manager (Batch Menu Option 6)
* **Commercial Support:** Contact support@pnwcomputers.com

**When reporting issues, please specify:**
- Which version you're using (original v2.21 or FIXED version)
- Operating System (Windows 10/11, build number)
- GPU type (NVIDIA/AMD/Intel, model)
- Whether you're running as administrator
- Complete error message (if applicable)

---

## 🙏 Acknowledgments

* **Microsoft Sysinternals Team** - For the incredible suite of diagnostic tools
* **Mark Russinovich** - For creating and maintaining Sysinternals
* **NVIDIA & AMD** - For providing diagnostic tools and APIs
* **TechPowerUp** - For GPU-Z, an excellent GPU monitoring tool
* **PowerShell Community** - For modules, patterns, and best practices
* **Contributors** - Everyone who has reported issues, suggested features, or contributed code
* **Beta Testers** - For finding the critical bugs that led to the FIXED release

---

## 📝 Version History

### v2.21 (FIXED) - October 2025
- ✅ Fixed critical startup crash (missing Initialize-Environment)
- ✅ Fixed tool verification (Menu Option 4)
- ✅ Fixed AMD multi-GPU detection
- ✅ Fixed SMART test running wrong operations
- ✅ Added GPU-Z size validation
- ✅ Improved error handling throughout
- ✅ Fixed memory leak in Windows Update test
- ✅ Enhanced network testing suite with PSPing integration

### v2.2 (Original) - September 2025
- Added GPU testing enhancements
- Added tool integrity verification
- Added dual report system
- Added advanced network speed testing

### v2.1 - December 2024
- Fixed memory usage calculation bug
- Added recommendations engine
- Improved report formatting

### v2.0 - November 2024
- Complete rewrite with modular functions
- Added interactive menu system
- Added batch launcher

---

## 📊 Statistics

![GitHub stars](https://img.shields.io/github/stars/Pnwcomputers/SystemTester)
![GitHub forks](https://img.shields.io/github/forks/Pnwcomputers/SystemTester)
![GitHub issues](https://img.shields.io/github/issues/Pnwcomputers/SystemTester)
![GitHub license](https://img.shields.io/github/license/Pnwcomputers/SystemTester)

**🎯 Transform your Windows diagnostics from a step-by-step process to AUTOMATED with FULL REPORTING!**

Built with ❤️ for efficiency, reliability, and a goal of close to zero-touch automation.

[⭐ Star this repo](https://github.com/Pnwcomputers/SystemTester) if it saved you time and effort!

---

*Tested on Windows 10 (1909+) and Windows 11 - Enterprise, Pro, and Home editions*

**Last Updated:** October 2025 | **Version:** 2.21 (FIXED) | **Status:** Production Ready

**⚠️ IMPORTANT:** Always use the `_FIXED` versions of the files for proper operation.
