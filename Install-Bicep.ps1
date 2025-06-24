# Downloads and installs latest Bicep CLI on Windows
$BicepDir = "C:\Program Files\bicep"
if (-not (Test-Path $BicepDir)) { New-Item -Path $BicepDir -ItemType Directory -Force }
Invoke-WebRequest -Uri https://github.com/Azure/bicep/releases/latest/download/bicep-win-x64.exe -OutFile "$BicepDir\bicep.exe"
$env:Path += ";$BicepDir"
[Environment]::SetEnvironmentVariable('Path', $env:Path, [System.EnvironmentVariableTarget]::Machine)
Write-Host "Bicep CLI installed to $BicepDir"