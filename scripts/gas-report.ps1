$env:REPORT_GAS="true"
$env:APPDATA="$PSScriptRoot\..\.hhdata\Roaming"
$env:LOCALAPPDATA="$PSScriptRoot\..\.hhdata\Local"
Set-Location "$PSScriptRoot\.."
npx hardhat test
