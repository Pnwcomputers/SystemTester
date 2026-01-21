# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

** Update 9-2-2025 **
** 🔧 General Improvements **
- Improved visual formatting using consistent separators (-------------------------------------) and color-coded headers.
- Run As Administrator Check/Approval for BAT file execution

** 🧠 Expanded Diagnostics **
New Diagnostic Modules Added:
- Test-OSHealth: Runs DISM and SFC scans for OS integrity.
- Test-StorageSMART: Collects SMART and reliability data from physical disks.
- Test-Trim: Checks SSD TRIM status.
- Test-NIC: Captures active network adapter details.
- Test-GPU: Summarizes GPU and DirectX info via dxdiag.
- Test-Power: Reports battery status and generates an energy report.
- Test-HardwareEvents: Scans for WHEA hardware error logs.

** Expanded Toolset: **
Added support for additional Sysinternals tools: sigcheck.exe, contig.exe, diskext.exe, listdlls.exe, clockres.exe.
- 🎨 Enhanced Console Output
- Color-coded console feedback:
- ✅ Success: Green
- ⚠️ Warning: Yellow
- ❌ Failure: Red
Recommendations are now printed with color-coded Write-Host output based on severity.

** 📊 Improved Reporting **
Executive Summary includes:
- Total tests run
- Success/failure counts
- Success rate (%)
- Total test duration

Detailed Results:
- Cleaned and truncated tool output for readability.
- Limited to first 15 lines per tool to avoid clutter.

Recommendations Section:
- Dynamically generated based on test outcomes.
- Includes memory, CPU, disk, SMART, TRIM, and WHEA insights.

Report Statistics:
- Displays file sizes and compression ratio between clean and detailed reports.

** 🧭 User Experience Enhancements **
Interactive Menu:
- Expanded to 17 options including new diagnostics and report generation.
- Clear prompts and color-coded choices for better navigation.

AutoRun Support:
- Automatically runs all tests and generates reports when -AutoRun is used.

Error Handling:
- Improved error messages with line number references.
- Graceful fallback for missing tools or failed tests.

** 🔧 Batch File Changes Made: **
Elevation Logic Overhaul:
- Replaced net session check with SID-based elevation detection (S-1-5-32-544) for better reliability on systems where the Server service is disabled.

Elevation Flag Handling:
- Added /elevated flag to prevent infinite loops and provide clearer error messaging when elevation fails or is cancelled.

PowerShell Script Selection:
- Added logic to prefer SystemTester_device_grouped.ps1 if available, falling back to SystemTester.ps1.

** New Execution Modes **
- Option 2: Classic test sequence
- Option 3: Grouped-by-device test sequence (-AutoRunByDevice)
- Execution Policy Fix Enhancement
- Improved Option 4 to set RemoteSigned for CurrentUser without triggering additional UAC prompts.

Help Section Updates:
- Clarified troubleshooting steps and added notes on new test modes.

General Cleanup
- Removed redundant title/color lines, improved messaging consistency, and ensured popd is used on exit to restore working directory.

---

# 🔄 Change Log - January 20, 2026

## 📊 Quick Stats
- **Commits Analyzed**: 25
- **Files Modified**: 5
- **New Files**: 4
- **Deleted Files**: 0

## 📝 Detailed Changes

### ✨ New Content
- Create generate_changelog.py (`37de35b`)
- Create .gitkeep (`d6bdaa7`)
- Create .gitkeep (`4bbbc52`)
- Create Troubleshooting.md (`fe7101a`)

### ♻️ Updates & Refactors
- Refactor Test-NetworkLatency function for clarity (#17) (`13ca550`)
- Update md-link-check.yml (`e325187`)
- Update md-link-check.yml (`d1d7b6d`)
- Update README.md (`88ab60e`)
- Update SystemTester.ps1 (#15) (`7095515`)
- Update SystemTester.ps1 (`1ff8eef`)
- Update README.md (`1915609`)
- Update README.md (`7211202`)
- Update README.md (`d85051f`)
- Update TROUBLESHOOTING.md (`b088497`)
- Update Troubleshooting.md (`b54e6ee`)
- Update TEST_BAT.bat (`edd62f2`)
- Update SystemTester.ps1 (`c175067`)
- Update SystemTester.bat (`4f1ba58`)
- Update SystemTester.ps1 (`b7df042`)
- update (`2f7989f`)
- update (`5d98fa4`)
- Update SystemTester.bat (`cc4a1dd`)

### 🗑️ Removals
- Delete Troubleshooting/Troubleshooting.md (`22b199b`)
- Delete Test.bat (`6df67c0`)

### ⚡ Other Changes
- Merge branch 'main' of https://github.com/Pnwcomputers/SystemTester (`59a7f44`)

## 📂 Files Touched
<details>
<summary>Click to view full file list</summary>

- `.github/workflows/md-link-check.yml`
- `README.md`
- `Reports/.gitkeep`
- `SystemTester.bat`
- `SystemTester.ps1`
- `Tools/.gitkeep`
- `Troubleshooting/TEST_BAT.bat`
- `docs/TROUBLESHOOTING.md`
- `generate_changelog.py`

</details>
## [Unreleased]
### Planned
- Network deployment options or network log storing
- Multi-language support
