## 🛠️ Troubleshooting

### "Sysinternals tools not found"
**Solution:** Use launcher Menu Option 5 to auto-download, or manually download from [live.sysinternals.com](https://live.sysinternals.com)

### "Execution policy" errors
**Solution:** Use launcher Menu Option 3, or run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`

### "Access denied" / Permission errors
**Solution:** Right-click launcher and choose "Run as administrator"

### Script crashes immediately on startup (v2.2 original only)
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
