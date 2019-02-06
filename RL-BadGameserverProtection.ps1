<#
.SYNOPSIS
Block bad Rocket League gameservers temporarily.
.DESCRIPTION
Identify Rocket League gameserver IP while joining, get its average ping out of three and add a temporary Nullroute if the ping is above a defined threshold.
.NOTES
- Keep in mind that the logic of this script does not protect against gameservers with good ping but high packet loss.
- The icmp response time and the ping displayed in game can vary by ~20ms. You can play with the -PingCutoff parameter to accommodate this if you are still getting too high ping.
.PARAMETER PingCutoff
Define the maximum allowed ping in miliseconds, default is 80.
.PARAMETER TimeOut
Define for how long a gameserver is blocked in seconds, default is 600 (10 minutes).
#>
param (
    [int]$PingCutoff = 80,
    [int]$TimeOut    = 600
)
$wid = [system.security.principal.windowsidentity]::GetCurrent()
$prp = New-Object System.Security.Principal.WindowsPrincipal($wid)
$adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
if (!$prp.IsInRole($adm))
{
	Write-Host "This script must be run in an elevated PowerShell window. Please launch an elevated session and try again." -ForegroundColor Yellow
	Break
}
$GameSrv = New-Object System.Object
$GameSrv | Add-Member -type NoteProperty -Name IP -Value ""
$GameSrv | Add-Member -type NoteProperty -Name Ping -Value 0
$GameSrv | Add-Member -type NoteProperty -Name PL -Value 0
$Srv = @()
for ($i=0;$i -lt 3;$i++){
    $Srv += $GameSrv
}
$NetAdapters = (Get-NetAdapter | ?{$_.MediaConnectionState -eq "Connected" -and $_.InterfaceDescription -notlike "*Xbox*" -and $_.InterfaceDescription -notlike "*VMware*"}).InterfaceIndex
$IPv4Regex = "(?:(?:1\d\d|2[0-5][0-5]|2[0-4]\d|0?[1-9]\d|0?0?\d)\.){3}(?:1\d\d|2[0-5][0-5]|2[0-4]\d|0?[1-9]\d|0?0?\d)"
$PingRegex = "\d{1,}ms"
$PLRegex = "[a-zA-Z\säöüëéïß]*\.$"
$TimeSpan = New-TimeSpan -Seconds $TimeOut
$RLfound = $true
while (1) {
    if (((Get-Process RocketLeague -ErrorAction SilentlyContinue).count) -eq 1){
        $RLfound = $true
        Get-NetTCPConnection -OwningProcess ((Get-Process RocketLeague).Id) -ea SilentlyContinue | Select RemoteAddress, RemotePort | Where-Object {$_.RemotePort -in 7000..9000 -or $_.RemotePort -in 2000..3300} |
            % {
                $CurrSrv = New-Object System.Object
                $CurrSrv | Add-Member -type NoteProperty -Name IP -Value $_.RemoteAddress
                $CurrSrv | Add-Member -type NoteProperty -Name Ping -Value 0
                $CurrSrv | Add-Member -type NoteProperty -Name PL -Value 0
                ping -4 -n 1 -w $PingCutoff*4 $CurrSrv.IP | Where-Object {($_ -match $IPv4Regex -and $_ -match $PingRegex) -or $_ -match $PLRegex} |
                    % {
                                                $Srv[2] = $Srv[1]
                        $Srv[1] = $Srv[0]
                        if ($_ -match $PLRegex){
                            $CurrSrv.PL = 1
                        }else{
                            $CurrSrv.Ping = [convert]::ToInt32(((([regex]$PingRegex).Match($_).Value) -replace "..$"), 10)
                        }
                        $Srv[0] = $CurrSrv
                        if (($Srv[0].IP -eq $Srv[1].IP -and $Srv[1].IP -eq $Srv[2].IP) -and ($Srv[0].IP -ne $GameSrv.IP)){
                            $GameSrv = $Srv[0]
                            Write-Host "Gameserver found:   " $GameSrv.IP -ForegroundColor Yellow
                            $GameSrv.PL += $Srv[1].PL
                            $GameSrv.PL += $Srv[2].PL
                            if ($GameSrv.PL -lt 3){
                                $GameSrv.Ping = [math]::Round(($Srv[0].Ping + $Srv[1].Ping + $Srv[2].Ping) / (3 - $GameSrv.PL))
                            }
                            if (($GameSrv.Ping -gt $PingCutoff) -or ($GameSrv.PL -gt 1)){
                                Write-Host "Average Ping:        $($GameSrv.Ping)ms" -ForegroundColor Red
                                Write-Host "Packets Lost:        $($GameSrv.PL)/3" -ForegroundColor Red
                                foreach ($NetAdapter in $NetAdapters){
                                    New-NetRoute -InterfaceIndex $NetAdapter -DestinationPrefix ($GameSrv.IP + "/32") -NextHop 0.0.0.0 -PolicyStore ActiveStore -ValidLifetime $TimeSpan -PreferredLifetime $TimeSpan | Out-Null
                                     Write-Host "Adding Nullroute for $($GameSrv.IP) on Interface #$($NetAdapter) for $($TimeSpan.TotalSeconds) Seconds" -ForegroundColor Red
                                }
                            }else{
                                Write-Host "Average Ping:        $($GameSrv.Ping)ms" -ForegroundColor Green
                                Write-Host "Packets Lost:        $($GameSrv.PL)/3" -ForegroundColor Green
                                Write-Host "Have Fun!" -ForegroundColor Green
                            }
                        }
                    }
            }
        sleep -m 500
    }else {
        if ($RLfound){
            Write-Host "None or too many Rocket League processes found!" -ForegroundColor Yellow
            $RLfound = $false
        }
        sleep -s 10
    }
}