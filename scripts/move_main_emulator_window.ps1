# Move Main Emulator Window to Right Side Middle

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WindowHelper {
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
}

public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}
"@

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  Move Main Emulator Window" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Get screen dimensions
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$screenWidth = $screen.Width
$screenHeight = $screen.Height

Write-Host "Screen resolution: $screenWidth x $screenHeight" -ForegroundColor Gray
Write-Host ""

$emulatorProcs = Get-Process | Where-Object {$_.ProcessName -like "*qemu*"}

$mainWindow = $null
$windowTitle = ""

$callback = {
    param($hWnd, $lParam)

    $processId = 0
    [WindowHelper]::GetWindowThreadProcessId($hWnd, [ref]$processId) | Out-Null

    foreach ($proc in $emulatorProcs) {
        if ($processId -eq $proc.Id) {
            if ([WindowHelper]::IsWindowVisible($hWnd)) {
                $title = New-Object System.Text.StringBuilder 256
                [WindowHelper]::GetWindowText($hWnd, $title, $title.Capacity) | Out-Null
                $titleStr = $title.ToString()

                # Look for the main Android Emulator window
                if ($titleStr -match "Android Emulator.*5554") {
                    $script:mainWindow = $hWnd
                    $script:windowTitle = $titleStr
                    return $false
                }
            }
        }
    }
    return $true
}

[WindowHelper]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null

if (-not $mainWindow) {
    Write-Host "[ERROR] Could not find main emulator window" -ForegroundColor Red
    exit 1
}

Write-Host "Found main window: $windowTitle" -ForegroundColor Green
Write-Host ""

# Get current window size
$rect = New-Object RECT
[WindowHelper]::GetWindowRect($mainWindow, [ref]$rect) | Out-Null

$currentWidth = $rect.Right - $rect.Left
$currentHeight = $rect.Bottom - $rect.Top

Write-Host "Window size: $currentWidth x $currentHeight" -ForegroundColor Gray
Write-Host "Current position: X=$($rect.Left), Y=$($rect.Top)" -ForegroundColor Gray

# Calculate new position (right side, vertically centered)
$margin = 20
$newX = $screenWidth - $currentWidth - $margin
$newY = [Math]::Max(0, ($screenHeight - $currentHeight) / 2)

Write-Host ""
Write-Host "Moving to: X=$newX, Y=$newY (right side, middle)" -ForegroundColor Yellow
Write-Host ""

# Move window
$SWP_NOSIZE = 0x0001
$SWP_NOZORDER = 0x0004
$SWP_SHOWWINDOW = 0x0040

$result = [WindowHelper]::SetWindowPos(
    $mainWindow,
    [IntPtr]::Zero,
    [int]$newX,
    [int]$newY,
    0,
    0,
    $SWP_NOSIZE -bor $SWP_NOZORDER -bor $SWP_SHOWWINDOW
)

if ($result) {
    Write-Host "[OK] Main emulator window moved successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "The emulator is now at:" -ForegroundColor Cyan
    Write-Host "  - Right side of screen (X: $newX)" -ForegroundColor White
    Write-Host "  - Vertically centered (Y: $newY)" -ForegroundColor White
} else {
    Write-Host "[ERROR] Failed to move window" -ForegroundColor Red
}

Write-Host ""
