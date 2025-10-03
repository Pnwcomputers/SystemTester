# 🧰 Portable Sysinternals System Tester

**Thumb-drive friendly, Windows hardware health check toolkit using Sysinternals applications**

A no-install PowerShell solution that runs a curated set of **Sysinternals** and Windows hardware diagnostics tools, then produces: **Clean Summary Report** (human-readable, de-noised) and **Detailed Report** (cleaned tool outputs). Perfect for **field diagnostics**, **baseline health checks**, and **handoff reports** to clients.

---

## ✨ Key Features

* 🖱️ **One-click Menu or Autorun** — interactive menu or `-AutoRun` parameter
* 🧹 **Output Cleaner** — removes banners, EULA text, usage blocks for readable reports
* 🧠 **Comprehensive Tests** — CPU, RAM, Disk, GPU, Network, OS Health, Windows Update status
* 🗂️ **Smart Reporting** — timestamped **Summary** + **Detailed** TXT reports with actionable recommendations
* 📦 **Fully Portable** — run from USB; no installation required
* 🧰 **Graceful Degradation** — missing tools detected and skipped automatically with helpful messages
* 🔐 **Robust Elevation Handling** — SID-based admin check (Windows Home compatible)
* 📥 **Auto-Download Tools** — built-in Sysinternals Suite downloader (no manual setup needed!)
* 🔄 **Windows Update Integration** — checks pending updates, history, and service status
* ⚡ **Modern PowerShell** — uses CIM instances (not deprecated WMI) for better performance

---

## 🧩 Requirements

* **OS:** Windows 10/11 (Windows Server supported)
* **PowerShell:** 5.1+ or PowerShell 7
* **Permissions:** Administrator rights recommended (some tests require elevation)
* **Internet:** Only needed for auto-download feature (optional)
* **Sysinternals Tools:** Auto-downloadable via launcher or manual installation

---

## 📁 Recommended Folder Structure

```
📂 SystemTester/
├── 📄 SystemTester.ps1          # Main PowerShell script
├── 📄 SystemTester_Launcher.bat # Batch launcher (recommended)
├── 📄 README.md                 # This file
├── 📄 LICENSE                   # MIT License
├── 📂 Sysinternals/             # Auto-created by launcher
│   ├── psinfo.exe
│   ├── coreinfo.exe
│   ├── pslist.exe
│   ├── handle.exe
│   ├── autorunsc.exe
│   └── ... (60+ other tools)
└── 📂 Reports/                  # Created when tests run
    ├── SystemTest_Clean_20250103_143022.txt
    └── SystemTest_Detailed_20250103_143022.txt
```

---

## 🚀 Quick Start

### **Option A: Batch Launcher (Recommended)**

1. Download or clone this repository
2. Run `SystemTester_Launcher.bat` (will request admin elevation)
3. Choose **Option 6** to auto-download Sysinternals Suite (first time only)
4. Choose **Option 1** for interactive menu or **Option 2** to run all tests
5. Reports are saved in the script directory

### **Option B: Direct PowerShell**

```powershell
# Interactive menu
powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1

# Run all tests automatically
powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1 -AutoRun

# Save reports to specific folder (future)
powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1 -AutoRun -OutputPath "E:\Reports"
```

### **First-Time Setup**

If Sysinternals tools are missing:
1. **Automatic:** Use launcher Menu Option 6 to download (~30-40 MB)
2. **Manual:** Download from [live.sysinternals.com](https://live.sysinternals.com), extract to `.\Sysinternals\`

---

## 🧪 Test Suites (15 Categories)

| # | Category | Description | Key Tools Used |
|---|----------|-------------|----------------|
| 1 | **System Information** | OS details, computer info, clock resolution | `psinfo`, `clockres`, CIM queries |
| 2 | **CPU Testing** | Architecture, performance benchmarks, top processes | `coreinfo`, stress test, process analysis |
| 3 | **RAM Testing** | Memory capacity, modules, usage patterns | CIM queries, `testlimit`, performance counters |
| 4 | **Storage Testing** | Drives, fragmentation, performance, SMART data | `du`, `contig`, `streams`, read/write tests |
| 5 | **Process Analysis** | Running processes, handles, process tree | `pslist`, `handle` |
| 6 | **Security Analysis** | Autorun entries, startup items | `autorunsc` |
| 7 | **Network Analysis** | Active connections, adapter info | `netstat`, `Get-NetAdapter` |
| 8 | **OS Health** | System file integrity, component store | `DISM`, `SFC` |
| 9 | **Storage SMART** | Drive health, reliability counters | `Get-PhysicalDisk`, WMI SMART |
| 10 | **SSD TRIM** | TRIM enablement status | `fsutil` |
| 11 | **Network Adapters** | Link status, speed, IP addresses | `Get-NetAdapter`, `Get-NetIPConfiguration` |
| 12 | **GPU/DirectX** | Graphics card info, DirectX version | `dxdiag` |
| 13 | **Power/Battery** | Battery health, energy report | `powercfg`, WMI Battery |
| 14 | **Hardware Events** | WHEA error logs (last 7 days) | Event Viewer (WHEA-Logger) |
| 15 | **Windows Update** | Pending updates, history, service status | Windows Update COM API |

---

## 📊 Sample Output

### Clean Summary Report
```
---------------------------------
  SYSTEM TEST REPORT (CLEANED)
---------------------------------
Date: 2025-01-03 14:30:22
Computer: DESKTOP-ABC123
User: JohnDoe
Drive: E:

EXECUTIVE SUMMARY:
-----------------
Total Tests Run: 28
Successful: 26
Failed: 2
Success Rate: 92.9%
Total Test Time: 347.2 seconds

KEY FINDINGS:
-------------
SYSTEM:
  OS: Microsoft Windows 11 Pro 10.0.22631
  Total RAM: 16 GB
  
CPU PERFORMANCE:
  Operations/sec: 15847293
  
MEMORY:
  Total RAM: 16 GB
  Usage: 62.3%
  
DISK PERFORMANCE:
  Write Speed: 487.3 MB/s
  Read Speed: 523.1 MB/s

WINDOWS UPDATE: 12 pending updates available

RECOMMENDATIONS:
----------------
• WINDOWS UPDATES - 12 updates pending, consider updating soon
• SYSTEM HEALTH GOOD - No critical issues detected
```

---

## 🔧 Launcher Menu Options

The batch launcher (`SystemTester_Launcher.bat`) provides:

1. **Run with Interactive Menu** — Select individual tests
2. **Run ALL Tests Automatically** — Complete system scan with auto-report
3. **Generate Report from Previous Results** — Re-generate from current session
4. **Fix PowerShell Execution Policy** — Set CurrentUser to RemoteSigned
5. **Verify Sysinternals Tools Installation** — Check what's installed/missing
6. **Download/Update Sysinternals Suite** — **NEW!** Auto-download from Microsoft
7. **Show Help / Troubleshooting** — Comprehensive troubleshooting guide
8. **Exit** — Close launcher

---

## 🛠️ Troubleshooting

### "Sysinternals tools not found"
**Solution:** Use launcher Menu Option 6 to auto-download, or manually download from [live.sysinternals.com](https://live.sysinternals.com)

### "Execution policy" errors
**Solution:** Use launcher Menu Option 4, or run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`

### "Access denied" / Permission errors
**Solution:** Right-click launcher and choose "Run as administrator"

### Windows Update check fails
**Solution:** Ensure Windows Update service is running; may require administrator rights

### Tests taking too long
**Expected:** Some tests are intentionally slow:
- CPU Performance: 10 seconds
- Power/Energy Report: 15 seconds
- Windows Update Search: 30-60 seconds
- DISM/SFC Scans: 5-15 minutes

---

## 🛡️ Privacy & Safety

* **Admin Rights:** Required for DISM, SFC, energy reports, SMART data, Windows Update queries
* **Report Contents:** Includes computer name, username, installed software paths
* **Data Sensitivity:** Reports may reveal system configuration—review before sharing
* **No Telemetry:** Script does not send data anywhere; purely local operation
* **Auto-Download:** Only downloads from official Microsoft servers (download.sysinternals.com)

---

## 📋 What's New in Version 2.0

### ✅ Implemented Features
* Windows Update status checking (pending updates, history, service status)
* Auto-download functionality for Sysinternals Suite
* Enhanced error handling with detailed messages throughout
* Migration from deprecated WMI to modern CIM instances
* Improved SMART data collection (legacy and modern APIs)
* Network adapter detailed information (link speed, IP, MAC)
* GPU/DirectX information via dxdiag
* Battery and power efficiency reporting
* Hardware error event logging (WHEA)
* SSD TRIM status checking
* 8-option launcher menu with tool verification
* Comprehensive help and troubleshooting system
* Better scope handling for PowerShell variables
* Async dxdiag handling with timeout
* Proper argument splitting for tools
* Memory calculation fixes (KB to GB conversions)
* Input validation in launcher
* File size validation for downloads
* ZIP extraction with overwrite support
* Dowload needed Sysinternals Suite Applications from within the Utility
* 

### 🔄 Architecture Improvements
* Replaced all `Get-WmiObject` with `Get-CimInstance`
* Added `-ErrorAction Stop` to all critical operations
* Consistent error message formatting
* Try/catch blocks in all test functions
* Null safety checks throughout
* Type-safe conversions with validation
* Clean temp file handling

---

## 🗺️ Roadmap

### Version 2.1
* Launcher awareness in PowerShell script (detect if launched via .bat)
* Better integration messages pointing to auto-download feature
* Tool integrity verification (file size, signature checks)
* Report history viewer in launcher
* Old report cleanup functionality
* Configuration file support (JSON) for test customization

### Version 2.2
* HTML report export with charts and graphs
* Baseline comparison mode (compare current vs. previous tests)
* Skip flags (`-SkipCPU`, `-SkipNetwork`, etc.)
* Tunable summary verbosity levels
* CSV export for data analysis
* Network throughput testing
* Advanced GPU diagnostics (if GPU-Z or similar available)

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

## 🤝 Contributing

Contributions welcome! Areas of interest:

* **Parsers:** New tool output cleaners
* **Tests:** Additional diagnostic modules (GPU, audio, peripherals)
* **Performance:** Optimization of slow operations
* **Documentation:** Tutorial videos, screenshots, wiki articles
* **Testing:** Pester unit tests, integration tests
* **Internationalization:** Multi-language support

**Before contributing:**
1. Open an issue to discuss large changes
2. Follow existing code style and patterns
3. Test on Windows 10 and Windows 11
4. Update README and help text
5. Run PSScriptAnalyzer if possible

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
* **Commercial Support:** Contact support@pnwcomputers.com

---

## 🙏 Acknowledgments

* **Microsoft Sysinternals Team** - For the incredible suite of diagnostic tools
* **Mark Russinovich** - For creating and maintaining Sysinternals
* **PowerShell Community** - For modules, patterns, and best practices
* **Contributors** - Everyone who has reported issues, suggested features, or contributed code

---

**Last Updated:** January 2025 | **Version:** 2.0 | **Status:** Production Ready
