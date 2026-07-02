$ErrorActionPreference = "Stop"
$env:APPDATA = "$PSScriptRoot\..\.hhdata\Roaming"
$env:LOCALAPPDATA = "$PSScriptRoot\..\.hhdata\Local"
$env:npm_config_cache = "D:\tmp\npm-cache"
Write-Host "Starting Hardhat node at http://127.0.0.1:8545 ..."
Set-Location "$PSScriptRoot\.."
npx hardhat node
