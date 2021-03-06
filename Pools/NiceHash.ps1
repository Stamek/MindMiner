<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateConfig "Do you want to mine on $($PoolInfo.Name) (>0.1 BTC every 24H, <0.001 BTC ~ weekly)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "22 min 30 sec"
}
if (!$Cfg) { return $PoolInfo }
if (!$Config.Wallet.BTC) { return $PoolInfo }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }
$Pool_Variety = 0.95

try {
	$Request = Get-UrlAsJson "https://api.nicehash.com/api?method=simplemultialgo.info"
}
catch { return $PoolInfo }

try {
	if ($Config.ShowBalance) {
		$RequestBalance = Get-UrlAsJson "https://api.nicehash.com/api?method=stats.provider&addr=$($Config.Wallet.BTC)"
	}
}
catch { }

if (!$Request) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$PoolInfo.Balance.Value = 0
	$RequestBalance.result.stats | ForEach-Object {
		$PoolInfo.Balance.Value += [decimal]($_.balance)
	}
}

if ($Config.SSL -eq $true) { $Pool_Protocol = "stratum+ssl" } else { $Pool_Protocol = "stratum+tcp" }

$Pool_Region = "usa"
# "eu", "usa", "hk", "jp", "in", "br"
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = "eu" }
	"$([eRegion]::China)" { $Pool_Region = "hk" }
	"$([eRegion]::Japan)" { $Pool_Region = "jp" }
}

$Request.result.simplemultialgo | Where-Object paying -GT 0 | ForEach-Object {
	$Pool_Algorithm = Get-Algo($_.name)
	if ($Pool_Algorithm) {
		$Pool_Host = "$($_.name).$Pool_Region.nicehash.com"
		$Pool_Port = $_.port
		if ($Config.SSL -eq $true) {
			$Pool_Port = "3" + $Pool_Port
		}

		$Divisor = 1000000000
		$Profit = [Double]$_.paying * (1 - 0.04) * $Pool_Variety / $Divisor
		$Profit = Set-Stat -Filename ($PoolInfo.Name) -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit

		$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
			Name = $PoolInfo.Name
			Algorithm = $Pool_Algorithm
			Info = $Config.Region
			InfoAsKey = $true
			Profit = $Profit
			Protocol = $Pool_Protocol
			Host = $Pool_Host
			Port = $Pool_Port
			PortUnsecure = $_.port
			User = "$($Config.Wallet.BTC).$($Config.WorkerName)"
			Password = $Config.Password
		})
	}
}

$PoolInfo