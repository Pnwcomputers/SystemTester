# Portable Sysinternals Windows System Testing Utility

<p align="center">
  <img src="assets/systemtester.png" alt="Thumb-drive friendly, no-install Windows hardware health check toolkit powered by Sysinternals and PowerShell." width="600"/>
</p>

![Automation Level](https://img.shields.io/badge/Automation-Zero%20Touch-green)
![Windows Support](https://img.shields.io/badge/Windows-10%20%7C%2011-blue)
![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Enterprise Ready](https://img.shields.io/badge/Enterprise-Ready-purple)
![GitHub issues](https://img.shields.io/github/issues/Pnwcomputers/SystemTester)
![Maintenance](https://img.shields.io/badge/Maintained-Yes-green)

**Thumb-drive friendly, no-install Windows hardware health check and malware triage toolkit** powered by **Sysinternals** and **PowerShell**.

A zero-dependency PowerShell solution that runs a comprehensive, curated set of Sysinternals and Windows diagnostic tools. Raw data is automatically processed into two clean deliverables: a **Clean Summary Report** (de-noised, human-readable, with recommendations) and a **Detailed Report** (full tool outputs).

**Target Use Cases:**
* Field diagnostics and client handoff reports.
* Establishing system baseline health and performance metrics.
* Bench technician malware triage and initial threat hunting.
* Quick hardware bottleneck identification (15–40 minute runtime based on system performance).

---

## 🚀 Key Features

* **Hardware & System Diagnostics:** Comprehensive checks covering CPU, memory, storage health, network stability, and driver integrity.
* **Malware Triage Layer:** Automated signature checks, system-process masquerade detection, unsigned DLL scanning, and VirusTotal hash lookups.
* **Event Log Threat Audit:** Native audit analyzing Defender history, security service crashes, event log clearing, and suspicious PowerShell execution.
* **GUI Launcher Integration:** One-key launching of pre-configured Process Explorer and Autoruns instances with EULAs pre-accepted and threat filters enabled.
* **Self-Aware Detection Filtering:** Smart script block and path filtering prevents the toolkit from flagging its own execution during scans.

---

## 📋 Toolkit Menu Architecture

### Main Launcher Menu (Entry Wrapper)

| Option | Command | Description |
| :--- | :--- | :--- |
| **1** | Run Interactive Menu | Opens the primary PowerShell sub-menu (options 1–21) for targeted testing and threat triage. |
| **2** | Run ALL Tests Automatically | Launches the entire diagnostic suite sequentially in zero-touch automated mode. |
| **3** | Fix PowerShell Execution Policy | Resolves local execution policy restrictions blocking PowerShell script execution. |
| **4** | Verify Tool Integrity | Audits digital signatures on bundled Sysinternals binaries to verify authenticity. |
| **5** | Download/Update Sysinternals Suite | Automatically fetches or updates the required Sysinternals toolkit binaries. |
| **6** | GPU Testing Tools Manager | Configures and manages optional GPU diagnostic utilities. |
| **7** | Help / Troubleshooting | Displays common error resolutions, execution policy guides, and usage details. |
| **8** | Exit | Safely closes the utility launcher. |

---

### Interactive Diagnostics Sub-Menu (Main Menu Option 1)

| Option | Category | Description |
| :--- | :--- | :--- |
| **1–15** | Hardware & System Diagnostics | Storage health, memory stress, CPU benchmarks, driver checks, and network performance. |
| **16** | Full Suite Execution | Zero-touch sequential execution of all sub-menu diagnostic tests. |
| **17–18** | Reports & Maintenance | Custom report generation, log cleanup, and workspace reset tools. |
| **19** | Malware & Threat Scan | Standalone 4-pass triage scan (Autoruns, Process Explorer, ListDLLs, Event Audit). |
| **20** | GUI Threat Launchers | Pre-configured Process Explorer & Autoruns threat-hunting shortcuts. |
| **21** | Event Log Threat Audit | Standalone 14-day lookback audit for high-signal indicators of compromise (IoCs). |

---

## ⚙️ Requirements & Execution Notes

* **Privileges:** Administrator rights recommended. Elevation is required for Security Log auditing, unsigned DLL checks (`ListDLLs`), and complete registry autostart scanning.
* **Dependencies:** Requires the [Sysinternals Suite](https://learn.microsoft.com/en-us/sysinternals/downloads/sysinternals-suite). Option 5 in the Main Launcher Menu auto-downloads the suite if missing.
* **Privacy Guarantee:** VirusTotal API lookups submit **SHA-256 file hashes only**. No actual binaries or local system files are ever uploaded (`VirusTotalSubmitUnknown` remains disabled).

---

## 🛡️ Antivirus & AMSI False-Positives

Because security utilities contain strings, patterns, and signature checks targeting known threats, real-time antivirus engines or PowerShell AMSI may occasionally trigger an alert.

* **AMSI Content Warnings (`ScriptContainedMaliciousContent`):** Current builds assemble threat-search keywords dynamically at runtime. Ensure you are executing an official, unmodified `SystemTester.ps1` release.
* **Code Signing:** Authenticode-signing `SystemTester.ps1` with a trusted internal or commercial certificate clears execution friction across client endpoints.
* **Folder Exclusions:** For persistent bench use, add the toolkit working directory to **Windows Security → Virus & Threat Protection → Exclusions**.
* **Integrity Auditing:** Use Main Menu Option 4 to verify digital signatures on bundled Sysinternals binaries prior to deployment.

---

*Maintained by Pacific Northwest Computers · jon@pnwcomputers.com*
