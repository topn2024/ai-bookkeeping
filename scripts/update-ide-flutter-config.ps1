# Update VS Code and Android Studio Flutter SDK path

Write-Host "Updating IDE Flutter configurations..." -ForegroundColor Green
Write-Host ""

# 1. Update VS Code User Settings
$vscodeUserSettings = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $vscodeUserSettings) {
    Write-Host "Found VS Code user settings at: $vscodeUserSettings"
    $content = Get-Content $vscodeUserSettings -Raw

    # Replace C:\flutter with D:\flutter
    $newContent = $content -replace 'C:\\\\flutter', 'D:\\flutter' -replace 'C:/flutter', 'D:/flutter' -replace 'C:\\flutter', 'D:\flutter'

    if ($content -ne $newContent) {
        Set-Content -Path $vscodeUserSettings -Value $newContent
        Write-Host "Updated VS Code user settings" -ForegroundColor Yellow
    } else {
        Write-Host "No Flutter path found in VS Code user settings" -ForegroundColor Gray
    }
} else {
    Write-Host "VS Code user settings not found, skipping..." -ForegroundColor Gray
}
Write-Host ""

# 2. Update Android Studio preferences
$androidStudioPaths = @(
    "$env:USERPROFILE\.AndroidStudio*",
    "$env:USERPROFILE\AppData\Roaming\Google\AndroidStudio*"
)

$foundAndroidStudio = $false
foreach ($pathPattern in $androidStudioPaths) {
    $dirs = Get-Item $pathPattern -ErrorAction SilentlyContinue
    foreach ($dir in $dirs) {
        $flutterConfigFile = Join-Path $dir.FullName "options\flutter.xml"
        if (Test-Path $flutterConfigFile) {
            Write-Host "Found Android Studio Flutter config at: $flutterConfigFile"
            $content = Get-Content $flutterConfigFile -Raw

            # Replace C:\flutter with D:\flutter
            $newContent = $content -replace 'C:\\flutter', 'D:\flutter' -replace 'C:/flutter', 'D:/flutter'

            if ($content -ne $newContent) {
                Set-Content -Path $flutterConfigFile -Value $newContent
                Write-Host "Updated Android Studio Flutter config" -ForegroundColor Yellow
                $foundAndroidStudio = $true
            }
        }
    }
}

if (-not $foundAndroidStudio) {
    Write-Host "Android Studio Flutter config not found, skipping..." -ForegroundColor Gray
}

Write-Host ""
Write-Host "IDE configuration update completed!" -ForegroundColor Green
