# Update Flutter path from C:\flutter to D:\flutter

# Get current user Path
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
Write-Host "Current User Path:"
Write-Host $userPath
Write-Host ""

# Replace C:\flutter\bin with D:\flutter\bin
$newPath = $userPath -replace 'C:\\flutter\\bin', 'D:\flutter\bin'

# Set new Path
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
Write-Host "Updated User Path:"
Write-Host $newPath
Write-Host ""
Write-Host "Environment variable updated successfully!"
