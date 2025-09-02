# 🚀 Portable Sysinternals System Tester (v1.0)

![Portability](https://img.shields.io/badge/Portable-Yes-brightgreen) ![Windows Support](https://img.shields.io/badge/Windows-10%20%7C%2011-blue) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue) ![Sysinternals](https://img.shields.io/badge/Sysinternals-Supported-purple) ![Maintenance](https://img.shields.io/badge/Maintained-Yes-green) ![GitHub issues](https://img.shields.io/github/issues/Pnwcomputers/PortableSysinternalsTester) ![License](https://img.shields.io/github/license/Pnwcomputers/PortableSysinternalsTester)

**Thumb-drive friendly Windows health check toolkit**

A no-install PowerShell solution that runs a curated set of **Sysinternals** and Windows diagnostics, then produces: **Clean Summary Report** (human-readable, de-noised) and **Detailed Report** (cleaned tool outputs). Perfect for **field diagnostics**, **baseline health checks**, and **handoff reports** to clients.

---

## ✨ Key Features

* **🖱️ One-click Menu or Autorun** — interactive menu or `-AutoRun`
* **🧹 Output Cleaner** — removes banners, EULA text, usage blocks
* **🧠 Comprehensive Tests** — CPU, RAM, Disk, Processes, Security (Autoruns), Network
* **🗂️ Smart Reporting** — timestamped **Summary** + **Detailed** TXT reports
* **📦 Fully Portable** — run from USB; no install required
* **🧰 Graceful Degradation** — missing tools are detected and skipped automatically

---

## 🧩 Requirements

Windows 10/11; PowerShell 5.1+ (or PowerShell 7); Sysinternals tools placed in `.\Sysinternals\` (the script auto-adds `-accepteula` where needed).

---

## Recommended Folder Structure:
- SystemTester.ps1
- RunSystemTester.bat
- Sysinternals
-   - psinfo.exe
    - coreinfo.exe
    - pslist.exe
    - testlimit.exe
    - du.exe
    - streams.exe
    -   -(optional) handle.exe, autorunsc.exe, contig.exe, sigcheck.exe, clockres.exe

---

## 🚀 Quick Start

- Option A — Interactive menu: run `RunSystemTester.bat`.
- Option B — Autorun everything + generate reports: run `RunSystemTester.bat` and choose option 2.
- Option C — Direct PowerShell (no BAT): interactive `powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1`; autorun `powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1 -AutoRun`; save reports to a specific folder `powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1 -AutoRun -OutputPath "E:\Reports"`.

**Reports created:** `SystemTest_Clean_YYYYMMDD_HHMMSS.txt` and `SystemTest_Detailed_YYYYMMDD_HHMMSS.txt`.

---

## 🧪 What It Runs

- **System Info:** `psinfo`, `clockres`, plus WMI OS/ComputerSystem overview.
- **CPU:** `coreinfo`, lightweight CPU perf loop, top process usage.
- **RAM:** WMI memory details, `testlimit -m 100`, `\Memory\Pages/sec` sampling.
- **Storage:** WMI disk overview, `du -l 2 C:\`, `streams -s C:\Windows\System32`, `contig -a C:\`, simple 10 MB read/write test.
- **Processes:** `pslist -t`, `handle -p explorer` (if present).
- **Security:** `autorunsc -a -c` (if present).
- **Network:** connection count via `netstat -an`.

---

## 🔧 Common Fixes

**Execution policy blocked:** run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force` or pick Option 4 in the launcher.
**Sysinternals tools not found:** create `.\Sysinternals\` and copy the tools there; missing tools are skipped with a friendly notice.

---

## 🛡️ Privacy & Safety

Admin rights are optional (some checks benefit from elevation). Reports include **computer name** and **username**—review before sharing outside your org. Autoruns/Streams can reveal executable paths—treat reports as **sensitive artifacts**.

---

## 🧭 Quick Links

Project home: `README` (this file).
Issues & feature requests: open a GitHub issue on this repo.
License: MIT (see `LICENSE`).
Changelog/Roadmap: see below.

---

## 📈 Roadmap

**v1.1**: optional GPU/SMART checks; `-Skip*` flags (e.g., `-SkipStorage`, `-SkipSecurity`); tunable summary verbosity (e.g., `-MaxLinesPerTool`).
**v1.2**: basic HTML report export; compressed artifacts output folder; improved parsers for `sigcheck`, `handle`, `autorunsc`.
**v2.0**: minimal WPF/WinUI menu alternative; pluggable “module” system; JSON config for per-tool args; signed releases.

---

## 🤝 Contributing

PRs welcome for: additional parsers/cleaners, new modules (GPU, SMART, network throughput), performance tweaks, and documentation. CI can run PSScriptAnalyzer; consider adding Pester tests for `Clean-ToolOutput`. Please open an issue first for large changes.

---

## 🔒 Security

For sensitive findings or potential security issues, contact `support@pnwcomputers.com`. Provide enough detail to reproduce; allow reasonable disclosure timelines.

---

## 📄 License

MIT — see `LICENSE`.

---

## 📞 Support & Contact

Documentation: this README.
Bugs/Features: open an issue.
General support: `support@pnwcomputers.com`.

---

## 📊 Repo Stats

![GitHub stars](https://img.shields.io/github/stars/Pnwcomputers/PortableSysinternalsTester) ![GitHub forks](https://img.shields.io/github/forks/Pnwcomputers/PortableSysinternalsTester) ![GitHub issues](https://img.shields.io/github/issues/Pnwcomputers/PortableSysinternalsTester) ![GitHub license](https://img.shields.io/github/license/Pnwcomputers/PortableSysinternalsTester)

**🎯 Baseline any Windows machine in minutes—not hours.**
