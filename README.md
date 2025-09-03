# 🧰 Portable Sysinternals System Tester

**Thumb-drive friendly, Windows hardware health check toolkit using Sysinternals applications**

A no-install PowerShell solution that runs a curated set of **Sysinternals** and Windows hardware diagnostics tools, then produces: **Clean Summary Report** (human-readable, de-noised) and **Detailed Report** (cleaned tool outputs). Perfect for **field diagnostics**, **baseline health checks**, and **handoff reports** to clients.

---

## ✨ Key Features

* **🖱️ One-click Menu or Autorun** — interactive menu or `-AutoRun`
* **🧹 Output Cleaner** — removes banners, EULA text, usage blocks
* **🧠 Comprehensive Tests** — CPU, RAM, Disk, Processes, Security (Autoruns), Network
* **🗂️ Smart Reporting** — timestamped **Summary** + **Detailed** TXT reports
* **📦 Fully Portable** — run from USB; no install required
* **🧰 Graceful Degradation** — missing tools are detected and skipped automatically
* **🔐 Robust Elevation Handling** — uses SID-based check for admin rights (no reliance on `net session`)
* **🧭 Device-Grouped Test Mode** — new `-AutoRunByDevice` option for structured diagnostics

---

## 🧩 Requirements

Windows 10/11; PowerShell 5.1+ (or PowerShell 7); Sysinternals tools placed in `.\Sysinternals\` (the script auto-adds `-accepteula` where needed).

---

## Recommended Folder Structure:
```
SystemTester.ps1
SystemTester.bat
Sysinternals\
├── psinfo.exe
├── coreinfo.exe
├── pslist.exe
├── testlimit.exe
├── du.exe
├── streams.exe
├── (optional) handle.exe, autorunsc.exe, contig.exe, sigcheck.exe, clockres.exe
TestResults\ (auto-created)
```

---

## 🚀 Quick Start

- **Option A — Interactive menu:** run `RunSystemTester.bat`.
- **Option B — Autorun everything (classic):** choose option 2 in the launcher.
- **Option C — Autorun grouped by device:** choose option 3 in the launcher.
- **Option D — Direct PowerShell (no BAT):**
  - Interactive: `powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1`
  - Autorun: `powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1 -AutoRun`
  - Grouped: `powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1 -AutoRunByDevice`
  - Save reports to folder: `powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1 -AutoRun -OutputPath "E:\Reports"`

**Reports created:**  
- `SystemTest_Clean_YYYYMMDD_HHMMSS.txt`  
- `SystemTest_Detailed_YYYYMMDD_HHMMSS.txt`

---

## 🧪 What It Runs

- **System Info:** `psinfo`, `clockres`, WMI OS/ComputerSystem overview
- **CPU:** `coreinfo`, perf loop, top process usage
- **RAM:** WMI memory details, `testlimit -m 100`, `\Memory\Pages/sec`
- **Storage:** WMI disk overview, `du`, `streams`, `contig`, read/write test
- **Processes:** `pslist`, `handle` (if present)
- **Security:** `autorunsc` (if present)
- **Network:** connection count via `netstat`

---

## 🔧 Common Fixes

- **Execution policy blocked:** run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force` or pick Option 4 in the launcher.
- **Sysinternals tools not found:** create `.\Sysinternals\` and copy the tools there; missing tools are skipped with a friendly notice.

---

## 🛡️ Privacy & Safety

Admin rights are optional (some checks benefit from elevation). Reports include **computer name** and **username**—review before sharing outside your org. Autoruns/Streams can reveal executable paths—treat reports as **sensitive artifacts**.

---

## 🧭 Quick Links

- Project home: `README` (this file).
- Issues & feature requests: open a GitHub issue on this repo.
- License: MIT (see `LICENSE`).
- Changelog/Roadmap: see below.

---

## 📈 Roadmap

- **v1.1**: optional GPU/SMART checks; `-Skip*` flags; tunable summary verbosity
- **v1.2**: HTML report export; compressed output folder; improved parsers
- **v2.0**:
  - SID-based elevation logic (Home-safe)
  - `/elevated` flag for UAC loop prevention
  - Device-grouped test mode (`-AutoRunByDevice`)
  - Launcher fallback to `SystemTester.ps1` if grouped script is missing
  - WPF/WinUI menu alternative (planned)
  - Pluggable module system; JSON config support
  - Signed releases

---

## 🤝 Contributing

PRs welcome for: additional parsers/cleaners, new modules (GPU, SMART, network throughput), performance tweaks, and documentation. CI can run PSScriptAnalyzer; consider adding Pester tests for `Clean-ToolOutput`. Please open an issue first for large changes.

---

## 🔒 Security

For sensitive findings or potential security issues, contact `support@pnwcomputers.com`. Provide enough detail to reproduce; allow reasonable disclosure timelines.
