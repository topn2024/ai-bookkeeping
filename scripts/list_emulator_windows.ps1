# List all emulator windows

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WindowHelper {
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

Write-Host "All Emulator Windows:" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

$emulatorProcs = Get-Process | Where-Object {$_.ProcessName -like "*emulator*" -or $_.ProcessName -like "*qemu*"}

$windows = @()

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

                $rect = New-Object RECT
                [WindowHelper]::GetWindowRect($hWnd, [ref]$rect) | Out-Null

                $width = $rect.Right - $rect.Left
                $height = $rect.Bottom - $rect.Top

                $script:windows += [PSCustomObject]@{
                    Handle = $hWnd
                    PID = $processId
                    Process = $proc.ProcessName
                    Title = $titleStr
                    Width = $width
                    Height = $height
                    X = $rect.Left
                    Y = $rect.Top
                }
            }
        }
    }
    return $true
}

[WindowHelper]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null

$windows | Format-Table -AutoSize Process, PID, Title, Width, Height, X, Y
Write-Host ""
Write-Host "Total windows found: $($windows.Count)" -ForegroundColor Green
