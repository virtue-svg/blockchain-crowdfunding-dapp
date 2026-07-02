$ErrorActionPreference="Stop"
$body=@{jsonrpc="2.0";method="eth_chainId";params=@();id=1}|ConvertTo-Json -Compress
$result=Invoke-RestMethod -Uri "http://127.0.0.1:8545" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 5
if($result.result -ne "0x7a69"){throw "Unexpected Chain ID: $($result.result)"}
Write-Host "[OK] Hardhat Local Chain ID 31337"
if(!(Test-Path "$PSScriptRoot\..\ignition\deployments\chain-31337\deployed_addresses.json")){throw "Contract is not deployed"}
Write-Host "[OK] Deployment record exists"
