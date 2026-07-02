param([int]$Seconds = 180)
$ErrorActionPreference = "Stop"
if ($Seconds -le 0) { throw "Seconds must be greater than zero." }
function Rpc($method,$params){$body=@{jsonrpc="2.0";method=$method;params=$params;id=1}|ConvertTo-Json -Compress;Invoke-RestMethod -Uri "http://127.0.0.1:8545" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 10}
Write-Host "Advancing Hardhat time by $Seconds seconds..."
Rpc "evm_increaseTime" @($Seconds)|Out-Null
Rpc "evm_mine" @()|Out-Null
$block=Rpc "eth_blockNumber" @()
Write-Host "Done. Current block number: $($block.result)"
