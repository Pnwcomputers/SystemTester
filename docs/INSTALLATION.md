# Installation Guide

## System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Windows 10 (1909) | Windows 11 |
| PowerShell | 5.1 | 5.1 (ships with Windows) |
| RAM | 4 GB | 8 GB+ |
| Free disk space | 500 MB (tools + reports) | 1 GB |
| Privileges | Standard user (limited) | Administrator (full test suite) |
| Internet | Optional | Required for first-time tool download |

Administrator rights are required for: DISM/SFC scans, energy reports, SMART data, Windows Update queries, and some handle/process tests.

---

## Method 1: Batch Launcher (Recommended)

1. Download or clone this repository to any location (USB drive, local folder, network share)
2. Run `SystemTester.bat` — it will request admin elevation automatically
3. Choose **Option 5** to download the Sysinternals Suite (~35 MB) on first use
4. Choose **Option 1** (interactive menu) or **Option 2** (run all tests automatically)

The batch launcher handles elevation, execution policy, and tool detection. No installation or system modification required.

---

## Method 2: Direct PowerShell

```powershell
# Interactive menu
powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1

# Run all tests automatically and generate reports
powershell -ExecutionPolicy Bypass -File .\SystemTester.ps1 -AutoRun
```

If you see an execution policy error, run this once:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

---

## Method 3: Git Clone

```bash
git clone https://github.com/Pnwcomputers/SystemTester.git
cd SystemTester
```

Then run `SystemTester.bat` or invoke the PS1 directly.

---

## First-Time Sysinternals Setup

SystemTester requires the Sysinternals Suite for most tests.

**Automatic (recommended):**
Use batch launcher **Menu Option 5** — downloads directly from Microsoft, VPN-compatible.

**Manual:**
1. Download from [live.sysinternals.com](https://live.sysinternals.com) or the [Microsoft Store page](https://docs.microsoft.com/sysinternals)
2. Extract all `.exe` files to `.\Sysinternals\` next to `SystemTester.ps1`

Minimum required tools for full test coverage:

| Tool | Required For |
|------|-------------|
| `psinfo.exe` | System information |
| `coreinfo.exe` | CPU architecture |
| `pslist.exe` | Process analysis |
| `handle.exe` | File handle scan |
| `psping.exe` | Network latency |
| `autorunsc.exe` | Security / autorun scan |
| `du.exe` | Disk usage |
| `clockres.exe` | Clock resolution |
| `contig.exe` | Disk fragmentation |

All other tools in the suite are used if present and gracefully skipped if absent.

---

## Optional GPU Tools

GPU stress testing tools are not required but extend testing capability.

Use batch launcher **Menu Option 6 → Option 5** to auto-download MSI Afterburner and FurMark directly to the `Tools\` folder.

Or download manually:
- **GPU-Z**: [techpowerup.com/gpuz](https://www.techpowerup.com/gpuz/)
- **MSI Afterburner**: msi.com/Landing/afterburner
- **FurMark**: [geeks3d.com/furmark](https://geeks3d.com/furmark)
- **HWiNFO64**: [hwinfo.com](https://www.hwinfo.com)

Place downloaded tools in the `Tools\` subfolder next to `SystemTester.ps1`.

---

## Portable USB Deployment

SystemTester is designed for USB deployment:

1. Copy the entire repository folder to a USB drive
2. Ensure the drive is formatted as NTFS or exFAT (FAT32 limits file size and may be read-only)
3. Run `SystemTester.bat` directly from the USB
4. Reports are saved to `<USB drive>\SystemTester\Reports\`

The script auto-detects its own location and never writes outside its own directory tree.

---

## Folder Structure

```
SystemTester/
+-- SystemTester.ps1         # Main PowerShell script
+-- SystemTester.bat         # Batch launcher (start here)
+-- README.md
+-- LICENSE
+-- Sysinternals/            # Auto-created by launcher Option 5
|   +-- psinfo.exe
|   +-- psping.exe
|   +-- autorunsc.exe
|   +-- ... (60+ tools)
+-- Tools/                   # GPU testing tools (optional)
|   +-- GPU-Z.exe
|   +-- MSIAfterburnerSetup.zip
|   +-- FurMark_Setup.exe
+-- Reports/                 # Auto-created on first report run
    +-- SystemTest_Clean_20260622_112034.txt
    +-- SystemTest_Detailed_20260622_112034.txt
    +-- energy-report.html
```

---

## Uninstall

Delete the folder. SystemTester makes no registry changes, installs no services, and creates no files outside its own directory. Sysinternals tools may leave EULA acceptance entries in `HKCU\Software\Sysinternals\` — delete these manually if desired.
