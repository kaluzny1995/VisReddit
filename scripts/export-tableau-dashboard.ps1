<#
.SYNOPSIS
    Opens "Emotion" and "EmotionAuthors" dashboards from EmotionAnalysis.twb
    in Tableau Public, shows each one fullscreen and saves a screenshot
    of each as a .png image.

.DESCRIPTION
    Tableau Public (free) does NOT support command-line or menu-based PDF export.
    This script:
      1. Opens the workbook in Tableau Public (maximized)
      2. For each dashboard: switches to it via the "Window" menu, enters
         fullscreen (Presentation Mode) and takes a screenshot of the window
      3. Saves the screenshots as "<DashboardName>.png"

    Prerequisites:
      - Tableau Public installed
#>

param(
    [string]$WorkbookPath,
    [string]$OutputDir
)

$RepoRoot = Split-Path $PSScriptRoot -Parent
if (-not $WorkbookPath) { $WorkbookPath = "$RepoRoot\EmotionAnalysis.twb" }
if (-not $OutputDir)    { $OutputDir    = "$RepoRoot\assets\images" }

$WaitMax    = 90
$DelayLoad  = 10
$DelayShort = 800
$DelayMed   = 2000

# Dashboard name -> output file mapping (names verified from .twb XML)
$Dashboards = @(
    @{ MenuName = "Emotion";         OutputName = "reddits_emotion_timeline_counts.png" }
    @{ MenuName = "EmotionAuthors";  OutputName = "reddits_emotion_topN_authors.png"   }
)

# Load assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, IntPtr dwExtraInfo);
    [DllImport("dwmapi.dll")]
    public static extern int DwmGetWindowAttribute(IntPtr hwnd, int dwAttribute, out RECT pvAttribute, int cbAttribute);
    public const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

# Make sure screenshots get real (physical) pixels on scaled displays
[Win32]::SetProcessDPIAware() | Out-Null

function Get-TableauHwnd {
    # Prefer the workbook window (title "Tableau Public - <Workbook>"). During
    # Presentation (fullscreen) mode the title drops the workbook part, so fall
    # back to the plain "Tableau Public" main window.
    $base = [System.IO.Path]::GetFileNameWithoutExtension($WorkbookPath)
    $work = Get-Process -Name "tabpublic" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -like "*$base*" } |
        Select-Object -First 1
    if ($work) { return $work.MainWindowHandle }

    $plain = Get-Process -Name "tabpublic" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -eq "Tableau Public" } |
        Select-Object -First 1
    if ($plain) { return $plain.MainWindowHandle }

    return [IntPtr]::Zero
}

function Focus-App {
    $hwnd = Get-TableauHwnd
    if ($hwnd -and $hwnd -ne [IntPtr]::Zero) {
        # 9 = SW_RESTORE, 3 = SW_MAXIMIZE -> run the window fullscreen-sized
        [Win32]::ShowWindow($hwnd, 9) | Out-Null
        [Win32]::ShowWindow($hwnd, 3) | Out-Null
        [Win32]::SetForegroundWindow($hwnd) | Out-Null
        Start-Sleep -Milliseconds 300
    }
}

function Wait-ForWindow($timeoutSec) {
    $elapsed = 0
    while ($elapsed -lt $timeoutSec) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        $h = Get-TableauHwnd
        if ($h -and $h -ne [IntPtr]::Zero) { return $true }
    }
    return $false
}
function Click-At($x, $y) {
    [Win32]::SetCursorPos($x, $y) | Out-Null
    Start-Sleep -Milliseconds 100
    [Win32]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [Win32]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds $DelayShort
}

function Get-AppWindow {
    $hwnd = Get-TableauHwnd
    if (-not $hwnd -or $hwnd -eq [IntPtr]::Zero) { return $null }
    try {
        return [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    } catch { return $null }
}

function Test-MenuBarReady {
    # Returns true once the full menu bar (File..Help incl. "Window") is exposed
    # in the UI Automation tree. On first launch the tree is often incomplete.
    $window = Get-AppWindow
    if (-not $window) { return $false }
    $menuCond = New-Object System.Windows.Automation.AndCondition(
        (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::MenuItem)),
        (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty, "Window")))
    return ($null -ne $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $menuCond))
}

function Take-Screenshot($outPath) {
    $hwnd = Get-TableauHwnd
    if (-not $hwnd -or $hwnd -eq [IntPtr]::Zero) { return $false }

    Focus-App
    Start-Sleep -Milliseconds 500

    # Get window bounds
    $rect = New-Object Win32+RECT
    $r = [Win32]::DwmGetWindowAttribute($hwnd, [Win32]::DWMWA_EXTENDED_FRAME_BOUNDS, [ref]$rect, [System.Runtime.InteropServices.Marshal]::SizeOf($rect))
    if ($r -ne 0) { return $false }

    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -le 0 -or $h -le 0) { return $false }

    Write-Host "         Window rect: ($($rect.Left),$($rect.Top)) ${w}x${h}"

    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, [System.Drawing.Size]::new($w, $h))
    $graphics.Dispose()

    # Crop to the dashboard region (relative to the captured window):
    #   X=214, Y=89, Width=1706, Height=886
    $cropRect = New-Object System.Drawing.Rectangle(214, 89, 1706, 886)
    $crop = New-Object System.Drawing.Bitmap($cropRect.Width, $cropRect.Height)
    $g = [System.Drawing.Graphics]::FromImage($crop)
    $g.DrawImage($bmp,
        (New-Object System.Drawing.Rectangle(0, 0, $cropRect.Width, $cropRect.Height)),
        $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $bmp.Dispose()

    $crop.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $crop.Dispose()
    return $true
}

function Invoke-WindowMenuItem($itemName) {
    # Opens the "Window" menu and invokes the entry named $itemName by
    # mouse-clicking its screen position. Mirrors the manually-verified working
    # sequence: capture the window element once, expand the menu via UIA, then
    # click the matching popup entry.
    Focus-App
    Start-Sleep -Milliseconds 400

    $window = Get-AppWindow
    if (-not $window) { Write-Warning "         Window not found."; return $false }

    # Find the "Window" entry of the menu bar (retry: tree can lag after launch)
    $menu = $null
    for ($try = 0; $try -lt 20 -and -not $menu; $try++) {
        $menu = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
            (New-Object System.Windows.Automation.AndCondition(
                (New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                    [System.Windows.Automation.ControlType]::MenuItem)),
                (New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::NameProperty, "Window")))))
        if (-not $menu) {
            $menu = $window.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
                (New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::NameProperty, "Window")))
        }
        if (-not $menu) { Start-Sleep -Milliseconds 500 }
    }
    if (-not $menu) { Write-Warning "         'Window' menu not found."; return $false }

    # Expand the menu via UIA
    try {
        $ec = $menu.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
        $ec.Expand()
    } catch {
        $r = $menu.Current.BoundingRectangle
        Click-At ([int]($r.X + $r.Width/2)) ([int]($r.Y + $r.Height/2))
    }
    Start-Sleep -Milliseconds $DelayShort

    # Find and click the target popup entry (retry on the same window element)
    for ($try = 0; $try -lt 20; $try++) {
        $items = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants,
            (New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                [System.Windows.Automation.ControlType]::MenuItem)))
        foreach ($it in $items) {
            if ($it.Current.Name -eq $itemName) {
                $r = $it.Current.BoundingRectangle
                # Accept genuine Window-menu popup entries: they appear below the
                # top menu bar (the bar's rows sit at y~23). The popup's x-position
                # varies, so do not filter on x.
                if ($r.Width -gt 0 -and $r.Height -gt 0 -and $r.Y -gt 100) {
                    $cx = [int]($r.X + $r.Width/2); $cy = [int]($r.Y + $r.Height/2)
                    Click-At $cx $cy
                    Start-Sleep -Milliseconds $DelayMed
                    return $true
                }
            }
        }
        Start-Sleep -Milliseconds 400
    }
    Write-Warning "         '$itemName' not found in Window menu."
    [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
    return $false
}

# ============================================================
#  Main
# ============================================================

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Tableau Public Dashboard -> PNG Exporter"    -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $WorkbookPath)) {
    Write-Error "Workbook not found: $WorkbookPath"
    exit 1
}
Write-Host "[1/4] Workbook : $WorkbookPath" -ForegroundColor Yellow

$tpExe = "C:\Program Files\Tableau\Tableau Public 2026.1\bin\tabpublic.exe"
if (-not (Test-Path $tpExe)) {
    $found = Get-ChildItem "C:\Program Files*\Tableau\*\bin\tabpublic.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($found) { $tpExe = $found.FullName }
    else { Write-Error "Tableau Public not found."; exit 1 }
}
Write-Host "[2/4] Tableau  : $tpExe" -ForegroundColor Yellow

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$savedFiles = @()

try {
    Get-Process -Name "tabpublic" -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    # Wait until the old instance is really gone (relaunching too early
    # makes the new one hand the file over and exit)
    for ($i = 0; $i -lt 15; $i++) {
        if (-not (Get-Process -Name "tabpublic" -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Seconds 1
    }
    Start-Sleep -Seconds 2

    # Remove Tableau auto-recovery leftovers -> avoids the recovery dialog
    Get-ChildItem (Split-Path $WorkbookPath) -Filter "~$([System.IO.Path]::GetFileNameWithoutExtension($WorkbookPath))*.twbr" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "[3/4] Opening workbook in Tableau Public..." -ForegroundColor Green
    Start-Process -FilePath $tpExe -ArgumentList "`"$WorkbookPath`""
    Write-Host "      Waiting up to ${WaitMax}s for window..."

    if (-not (Wait-ForWindow -timeoutSec $WaitMax)) {
        Write-Error "Tableau Public did not appear within ${WaitMax}s."
        exit 1
    }

    # Wait until the WORKBOOK is actually loaded (status bar appears), not just
    # the start page, and until the menu bar is fully exposed by UI Automation
    # (the tree is often incomplete/truncated right after a fresh launch).
    $loaded = $false
    for ($i = 0; $i -lt $WaitMax; $i += 2) {
        $w = Get-AppWindow
        if ($w) {
            $sbCond = New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
                'm_statusBarStatsPaneLabel')
            if ($w.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $sbCond)) {
                # give the UI tree a moment to settle, then confirm the menu bar
                Start-Sleep -Seconds 2
                if (Test-MenuBarReady) { $loaded = $true; break }
            }
        }
        Start-Sleep -Seconds 2
    }
    if ($loaded) { Write-Host "      Workbook loaded and UI ready." } else { Write-Warning "      Workbook load not confirmed; continuing anyway." }

    # Let the freshly launched app fully settle: the Qt menu accessibility
    # provider only becomes reliably queryable a few seconds after the UI is up.
    Write-Host "      Letting the application settle..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 8
    Focus-App
    Start-Sleep -Milliseconds $DelayMed

    Write-Host ""
    Write-Host "[4/4] Exporting dashboards as screenshots..." -ForegroundColor Green

    foreach ($dash in $Dashboards) {
        $dashName   = $dash.MenuName
        $outputName = $dash.OutputName
        Write-Host "      -> '$dashName' (-> $outputName)..." -ForegroundColor Cyan

        $selected = Invoke-WindowMenuItem $dashName
        if (-not $selected) {
            Write-Warning "         Could not switch to '$dashName'. Capturing current view."
        }
        [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
        Start-Sleep -Milliseconds 300

        # Wait for the dashboard to fully render in the (maximized) window
        Start-Sleep -Seconds 5
        Focus-App
        Start-Sleep -Milliseconds 500

        $pngPath = Join-Path $OutputDir $outputName
        Write-Host "         Taking screenshot..." -ForegroundColor DarkGray
        if (Take-Screenshot $pngPath) {
            $savedFiles += $pngPath
            Write-Host "         OK: $pngPath" -ForegroundColor Green
        } else {
            Write-Warning "         FAILED: Could not take screenshot for '$dashName'."
        }
        # Make sure no menu/popup is left open
        [System.Windows.Forms.SendKeys]::SendWait("{ESC}")
    }

    Write-Host ""
    Write-Host "Done!" -ForegroundColor Green
    foreach ($f in $savedFiles) { Write-Host "   Saved: $f" -ForegroundColor Cyan }

} finally {
    Write-Host ""
    Write-Host "Closing Tableau Public..." -ForegroundColor DarkGray
    Get-Process -Name "tabpublic" -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Remove Tableau auto-recovery leftovers (~*.twbr) created during the run
    $base = [System.IO.Path]::GetFileNameWithoutExtension($WorkbookPath)
    Get-ChildItem (Split-Path $WorkbookPath) -Filter "~${base}*.twbr" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Host "Finished." -ForegroundColor DarkGray
}
