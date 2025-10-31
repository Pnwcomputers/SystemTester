# 🧰 Portable Sysinternals System Tester v2.2

**Thumb-drive friendly, no-install Windows hardware health check toolkit** powered by **Sysinternals** and **PowerShell**.

A zero-dependency **PowerShell solution** that runs a comprehensive, curated set of Sysinternals and Windows diagnostic tools. It then processes the raw data to produce two essential reports: a **Clean Summary Report** (human-readable, de-noised, with recommendations) and a **Detailed Report** (cleaned tool outputs).

**The essential utility for:**
* Field diagnostics and client handoff reports.
* Establishing a system baseline health check.
* Quickly identifying performance bottlenecks.

---

## 🚀 NEW in v2.2: Advanced Network Speed & Latency Testing

Version 2.2 introduces a complete **Network Speed Test Suite** (Menu Option 8) for in-depth connectivity and performance analysis, integrated directly into the clean reporting system.

### Key New Capabilities:

* 🖱️ **One-click Menu or Autorun** — interactive menu or `-AutoRun` parameter
* 🧹 **Output Cleaner** — removes banners, EULA text, usage blocks for readable reports
* 🧠 **Comprehensive Tests** — CPU, RAM, Disk, GPU, Network, OS Health, Windows Update status
* 🎮 **Enhanced GPU Testing** — Multi-GPU support, NVIDIA/AMD vendor tools, display configuration
* 🗂️ **Smart Reporting** — timestamped **Summary** + **Detailed** TXT reports with actionable recommendations
* 📦 **Fully Portable** — run from USB; no installation required
* 🧰 **Graceful Degradation** — missing tools detected and skipped automatically with helpful messages
* 🔐 **Robust Elevation Handling** — reliable admin detection (Windows Home compatible)
* 📥 **Auto-Download Tools** — built-in Sysinternals Suite downloader (no manual setup needed!)
* 🔄 **Windows Update Integration** — checks pending updates, history, and service status
* ⚡ **Modern PowerShell** — uses CIM instances (not deprecated WMI) for better performance
* 🛡️ **Tool Integrity Verification** — digital signature checking for Sysinternals tools

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
├── 📄 SystemTester.ps1          # Main PowerShell script
├── 📄 SystemTester.bat          # Batch launcher (recommended)
├── 📄 README.md                 # This file
├── 📄 LICENSE                   # MIT License
├── 📂 Sysinternals/             # Auto-created by launcher
│   ├── psinfo.exe
│   ├── coreinfo.exe
│   ├── pslist.exe
│   ├── handle.exe
│   ├── autorunsc.exe
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
| 7 | **FULL Network Analysis** | Active connections, adapter info | `netstat`, `Get-NetAdapter`, `psping`,`Test-NetConncetion` |
| 8 | **OS Health** | System file integrity, component store | `DISM`, `SFC` |
| 9 | **Storage SMART** | Drive health, reliability counters | `Get-PhysicalDisk`, WMI SMART |
| 10 | **SSD TRIM** | TRIM enablement status | `fsutil` |
| 11 | **Network Adapters** | Link status, speed, IP addresses | `Get-NetAdapter`, `Get-NetIPConfiguration` |
| 12 | **GPU (Enhanced)** | Multi-GPU info, vendor tools, memory | CIM, `dxdiag`, `nvidia-smi`, GPU-Z |
| 12a | **Basic GPU Info** | Details, displays, drivers, DirectX, OpenGL | CIM queries, `dxdiag` |
| 12b | **Vendor-Specific** | NVIDIA/AMD metrics, temperatures, utilization | `nvidia-smi`, AMD registry |
| 12c | **GPU Memory** | VRAM capacity, usage, performance counters | CIM, performance counters |
| 13 | **Power/Battery** | Battery health, energy report | `powercfg`, WMI Battery |
| 14 | **Hardware Events** | WHEA error logs (last 7 days) | Event Viewer (WHEA-Logger) |
| 15 | **Windows Update** | Pending updates, history, service status | Windows Update COM API |

---

## 📊 Sample Output

### Clean Summary Report
```
=========================================
  SYSTEM TEST REPORT v2.1
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
• INFO: GPU drivers are over 1 year old
  → Update to latest drivers for best performance
  → NVIDIA: GeForce Experience or nvidia.com
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
4. **Verify Tool Integrity** — Check digital signatures and file sizes
5. **Download/Update Sysinternals Suite** — Auto-download from Microsoft (~35 MB)
6. **GPU Testing Tools Manager** — **NEW!** Download and manage GPU testing tools
   - GPU-Z installation assistant
   - NVIDIA tools verification (nvidia-smi)
   - AMD driver detection
   - Tool recommendations (FurMark, 3DMark, etc.)
7. **Help / Troubleshooting** — Comprehensive troubleshooting guide
8. **Exit** — Close launcher

### GPU Testing Sub-Menu (PowerShell Option 12)

When you select GPU testing in the PowerShell menu, you can:
* **12** - Run all GPU tests (comprehensive)
* **12a** - Basic GPU info only (fastest, ~3-5 seconds)
* **12b** - Vendor-specific tools (NVIDIA-SMI, AMD)
* **12c** - GPU memory testing

---

## 🛠️ Troubleshooting

### "Sysinternals tools not found"
**Solution:** Use launcher Menu Option 5 to auto-download, or manually download from [live.sysinternals.com](https://live.sysinternals.com)

### "Execution policy" errors
**Solution:** Use launcher Menu Option 3, or run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`

### "Access denied" / Permission errors
**Solution:** Right-click launcher and choose "Run as administrator"

### Windows Update check fails
**Solution:** Ensure Windows Update service is running; may require administrator rights

### GPU tests show "SKIPPED"
**Solution:** 
- For NVIDIA: Install latest drivers from nvidia.com
- For AMD: Install latest drivers from amd.com/support
- nvidia-smi is included with NVIDIA drivers
- Some GPU tests don't require special tools and should always work

### Tests taking too long
**Expected:** Some tests are intentionally slow:
- CPU Performance: 10 seconds
- Power/Energy Report: 15 seconds (admin only)
- Windows Update Search: 30-90 seconds
- DISM/SFC Scans: 5-15 minutes each (admin only)
- DirectX Diagnostics (dxdiag): Up to 45 seconds

---

## 🛡️ Privacy & Safety

* **Admin Rights:** Required for DISM, SFC, energy reports, SMART data, Windows Update queries
* **Report Contents:** Includes computer name, username, installed software paths, hardware details
* **Data Sensitivity:** Reports may reveal system configuration—review before sharing
* **No Telemetry:** Script does not send data anywhere; purely local operation
* **Auto-Download:** Only downloads from official Microsoft servers (download.sysinternals.com)
* **GPU Tools:** GPU-Z must be downloaded manually from techpowerup.com (launcher opens browser)

---

## 📋 What's New in Version 2.2

### Key New Capabilities:

| Feature | Description |
| :--- | :--- |
| **Local Connectivity** | Tests local network, default gateway reachability (`Test-NetConnection`). |
| **Internet Reachability** | Connectivity tests to multiple endpoints (Google DNS, Cloudflare DNS, Google.com, Microsoft.com). Includes port-specific testing (DNS 53, HTTPS 443). |
| **Latency Testing** | Detailed ping tests to multiple targets with round-trip time measurements. |
| **PSPing Integration** | Advanced latency and TCP bandwidth capacity testing for connection quality analysis (requires `psping.exe` in Sysinternals folder). |
| **DNS Resolution Speed** | Measures DNS lookup speed for multiple domains in milliseconds. |
| **Network MTU Discovery** | Checks for standard MTU (1500 bytes) without fragmentation to help identify network configuration issues. |

---

## 🗺️ Roadmap

### Version 2.3
* HTML report export with charts and graphs
* Baseline comparison mode (compare current vs. previous tests)
* Skip flags (`-SkipCPU`, `-SkipNetwork`, etc.)
* CSV export for data analysis
* Network throughput testing
* Memory leak detection
* Audio device testing

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
- **AMD:** Registry-based driver detection
  - Driver version and date
  - GPU identification

**GPU Memory (Option 12c):**
- Total VRAM capacity
- Active GPU process detection
- Performance counter integration

### GPU Tool Requirements

| Tool | Required For | Included With |
|------|--------------|---------------|
| CIM/WMI | Basic info | Windows (always available) |
| dxdiag | DirectX info | Windows (always available) |
| nvidia-smi | NVIDIA metrics | NVIDIA drivers |
| Registry | AMD detection | Windows (always available) |
| GPU-Z | Advanced monitoring | Manual download (optional) |

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

* **Parsers:** New tool output cleaners
* **Tests:** Additional diagnostic modules (audio, peripherals, temperatures)
* **GPU Tools:** Additional vendor integrations (Intel Arc, etc.)
* **Performance:** Optimization of slow operations
* **Documentation:** Tutorial videos, screenshots, wiki articles
* **Testing:** Pester unit tests, integration tests
* **Internationalization:** Multi-language support

**Before contributing:**
1. Open an issue to discuss large changes
2. Follow existing code style and patterns
3. Test on Windows 10 and Windows 11
4. Test with multiple GPU types if possible
5. Update README and help text
6. Run PSScriptAnalyzer if possible

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
* Affected versions
* Potential impact assessment
* Suggested remediation (if any)

---

## 📞 Support

* **Documentation Issues:** Open a GitHub issue
* **Feature Requests:** Start a GitHub discussion
* **General Questions:** Check the Help section in launcher (Option 7)
* **GPU Testing Help:** See GPU Tools Manager (Batch Menu Option 6)
* **Commercial Support:** Contact support@pnwcomputers.com

---

## 🙏 Acknowledgments

* **Microsoft Sysinternals Team** - For the incredible suite of diagnostic tools
* **Mark Russinovich** - For creating and maintaining Sysinternals
* **NVIDIA & AMD** - For providing diagnostic tools and APIs
* **TechPowerUp** - For GPU-Z, an excellent GPU monitoring tool
* **PowerShell Community** - For modules, patterns, and best practices
* **Contributors** - Everyone who has reported issues, suggested features, or contributed code

---

**Last Updated:** January 2025 | **Version:** 2.1 | **Status:** Production Ready
