# Ink Wash Canvas - full test suite. Run after EVERY change.
# Usage: powershell -ExecutionPolicy Bypass -File test\run-tests.ps1 [-NoBrowser]
# Steps: 1) JS syntax  2) stubbed init smoke  3) visual selftests (ink & oil) -> PNG
param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$testDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path -Parent $testDir

# --- 1. syntax ---
$html = [IO.File]::ReadAllText("$repo\ink-wash-canvas.html")
$m = [regex]::Match($html, '(?s)<script>(.*)</script>')
if (-not $m.Success) { Write-Host 'FAIL: cannot extract script'; exit 1 }
[IO.File]::WriteAllText("$env:TEMP\iwc-main.js", $m.Groups[1].Value)
node --check "$env:TEMP\iwc-main.js" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host 'FAIL: syntax'; exit 1 }
Write-Host 'PASS: syntax'

# --- 2. init-path smoke (stub DOM/WebGL, catches TDZ/order bugs) ---
node "$testDir\smoke.js" | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host 'FAIL: smoke init'; exit 1 }
Write-Host 'PASS: smoke init'

if ($NoBrowser) { Write-Host 'ALL TESTS PASS (no-browser mode)'; exit 0 }

# --- 3. visual selftests -> PNG (EnumWindows + PrintWindow: reliable, no focus steal) ---
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class WinCap {
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
"@
# NOTE: EnumWindows sees nothing in this automation session; Get-Process MainWindowTitle works.
# NOTE: PrintWindow cannot capture WebGL surfaces -> use real-screen CopyFromScreen
#       (window is briefly foregrounded at a fixed rect; ~2s focus steal per test).
function Get-DoneProc {
  # exact match = our --app window (user tabs carry ' - Profile - Edge' suffix)
  Get-Process msedge -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -eq 'SELFTEST-DONE' } | Select-Object -First 1
}
Get-DoneProc | ForEach-Object { $_.CloseMainWindow() | Out-Null }  # cleanup stale
Start-Sleep -Seconds 2

function Invoke-VisualTest([string]$query, [string]$outPng, [int]$maxWaitSec) {
  $u = ($repo -replace '\\', '/')
  # dedicated profile + app window at FIXED rect (resizing later would wipe the canvas)
  $x = 60; $y = 60; $w = 1280; $h = 800
  Start-Process msedge "--user-data-dir=$env:TEMP\iwc-edge-test --no-first-run --window-position=$x,$y --window-size=$w,$h --app=file:///$u/ink-wash-canvas.html?$query"
  $p = $null
  for ($i = 0; $i -lt $maxWaitSec; $i += 2) {
    Start-Sleep -Seconds 2
    $p = Get-DoneProc
    if ($p) { break }
  }
  if (-not $p) { Write-Host "FAIL: visual $query (timeout waiting SELFTEST-DONE)"; return $false }
  $hwnd = $p.MainWindowHandle
  [WinCap]::SetForegroundWindow($hwnd) | Out-Null
  Start-Sleep -Milliseconds 1200
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $y, 0, 0, $bmp.Size)
  $g.Dispose()
  $bmp.Save($outPng, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  $p.CloseMainWindow() | Out-Null
  Start-Sleep -Seconds 2
  Write-Host "PASS: visual $query -> $outPng"
  return $true
}
$ok1 = Invoke-VisualTest 'selftest' "$testDir\out-ink.png" 70
$ok2 = Invoke-VisualTest 'selftest=oil' "$testDir\out-oil.png" 50
if ($ok1 -and $ok2) { Write-Host 'ALL TESTS PASS' } else { exit 1 }
