# Move Emulator Window to Right Side Middle of Screen

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WindowHelper {
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

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
Write-Host "  Move Emulator Window" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Get screen dimensions
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$screenWidth = $screen.Width
$screenHeight = $screen.Height

Write-Host "Screen resolution: $screenWidth x $screenHeight" -ForegroundColor Gray
Write-Host ""

# Find emulator processes
$emulatorProcs = Get-Process | Where-Object {$_.ProcessName -like "*emulator*" -or $_.ProcessName -like "*qemu*"}

if (-not $emulatorProcs) {
    Write-Host "[ERROR] Emulator process not found" -ForegroundColor Red
    Write-Host "Please make sure the emulator is running" -ForegroundColor Yellow
    exit 1
}

Write-Host "Found emulator processes:" -ForegroundColor Green
$emulatorProcs | ForEach-Object {
    Write-Host "  - $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Gray
}
Write-Host ""

# Find emulator window from any of the processes
$emulatorWindow = $null
$windowTitle = ""

$callback = {
    param($hWnd, $lParam)

    $processId = 0
    [WindowHelper]::GetWindowThreadProcessId($hWnd, [ref]$processId) | Out-Null

    foreach ($proc in $emulatorProcs) {
        if ($processId -eq $proc.Id) {
            $title = New-Object System.Text.StringBuilder 256
            [WindowHelper]::GetWindowText($hWnd, $title, $title.Capacity) | Out-Null
            $titleStr = $title.ToString()

            # Accept any window with a title from emulator processes
            if ($titleStr.Length -gt 0) {
                Write-Host "  Checking window: '$titleStr' (PID: $processId)" -ForegroundColor Gray
                $script:emulatorWindow = $hWnd
                $script:windowTitle = $titleStr
                return $false  # Use the first window with a title
            }
        }
    }
    return $true  # Continue enumeration
}

[WindowHelper]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null

if (-not $emulatorWindow) {
    Write-Host "[ERROR] Could not find emulator window" -ForegroundColor Red
    exit 1
}

Write-Host "Found window: $windowTitle" -ForegroundColor Green
Write-Host ""

# Get current window size
$rect = New-Object RECT
[WindowHelper]::GetWindowRect($emulatorWindow, [ref]$rect) | Out-Null

$currentWidth = $rect.Right - $rect.Left
$currentHeight = $rect.Bottom - $rect.Top

Write-Host "Current window size: $currentWidth x $currentHeight" -ForegroundColor Gray

# Calculate new position (right side, middle)
$windowWidth = $currentWidth
$windowHeight = $currentHeight

# Position on right side with some margin
$margin = 20
$newX = $screenWidth - $windowWidth - $margin
$newY = [Math]::Max(0, ($screenHeight - $windowHeight) / 2)

Write-Host "Moving to: X=$newX, Y=$newY" -ForegroundColor Yellow
Write-Host ""

# Move window
$SWP_NOSIZE = 0x0001
$SWP_NOZORDER = 0x0004
$result = [WindowHelper]::SetWindowPos(
    $emulatorWindow,
    [IntPtr]::Zero,
    [int]$newX,
    [int]$newY,
    0,
    0,
    $SWP_NOSIZE -bor $SWP_NOZORDER
)

if ($result) {
    Write-Host "[OK] Window moved successfully!" -ForegroundColor Green
    Write-Host "Emulator is now positioned at the right side middle of the screen" -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] Failed to move window" -ForegroundColor Red
}

Write-Host ""
