$ErrorActionPreference = "Stop"
$env:APPDATA = "$PSScriptRoot\..\.hhdata\Roaming"
$env:LOCALAPPDATA = "$PSScriptRoot\..\.hhdata\Local"
$env:npm_config_cache = "D:\tmp\npm-cache"
Set-Location "$PSScriptRoot\.."
npx hardhat ignition deploy .\ignition\modules\Crowdfunding.js --network localhost --reset
