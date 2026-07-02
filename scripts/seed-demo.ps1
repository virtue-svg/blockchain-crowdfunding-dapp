$ErrorActionPreference = "Stop"
$env:APPDATA = "$PSScriptRoot\..\.hhdata\Roaming"
$env:LOCALAPPDATA = "$PSScriptRoot\..\.hhdata\Local"
$env:npm_config_cache = "D:\tmp\npm-cache"
Set-Location "$PSScriptRoot\.."
Write-Host "Creating demo crowdfunding projects ..."
npm run seed-demo
