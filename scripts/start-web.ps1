$ErrorActionPreference = "Stop"
$env:npm_config_cache = "D:\tmp\npm-cache"
Set-Location "$PSScriptRoot\.."
npm run dev
