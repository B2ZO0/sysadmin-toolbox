function Invoke-PingSweep {
    <#
    .SYNOPSIS
        Pings every address of a subnet in parallel and lists the ones that answer, with their name.
    .EXAMPLE
        Invoke-PingSweep -Subnet 192.0.2.0/24
    .EXAMPLE
        Invoke-PingSweep 198.51.100.0/26 -ResolveNames | Export-Csv alive.csv -NoTypeInformation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Subnet,
        [ValidateRange(100, 10000)][int]$TimeoutMs = 800,
        [switch]$ResolveNames,
        [switch]$IncludeDown
    )
    $addresses = @(Get-SubnetAddress -Subnet $Subnet)
    $pings = foreach ($ip in $addresses) {
        $p = New-Object System.Net.NetworkInformation.Ping
        [pscustomobject]@{ IP = $ip; Ping = $p; Task = $p.SendPingAsync($ip, $TimeoutMs) }
    }
    foreach ($x in $pings) {
        $reply = $null
        try { $reply = $x.Task.GetAwaiter().GetResult() } catch { Write-Verbose "$($x.IP): $($_.Exception.Message)" }
        $x.Ping.Dispose()
        $up = $reply -and $reply.Status -eq 'Success'
        if (-not $up -and -not $IncludeDown) { continue }
        $name = $null
        if ($up -and $ResolveNames) { try { $name = [System.Net.Dns]::GetHostEntry($x.IP).HostName } catch { $name = $null } }
        [pscustomobject]@{ IP = $x.IP; Status = $(if ($up) { 'Up' } else { 'Down' }); LatencyMs = $(if ($up) { $reply.RoundtripTime }); Name = $name }
    }
}

function Get-SubnetAddress {
    <#
    .SYNOPSIS
        Lists the usable host addresses of an IPv4 subnet in CIDR notation.
    .EXAMPLE
        Get-SubnetAddress 192.0.2.0/30
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Subnet)
    if ($Subnet -notmatch '^(\d{1,3}(\.\d{1,3}){3})/(\d{1,2})$') { throw "Use CIDR notation, for example 192.0.2.0/24 (got '$Subnet')." }
    $prefix = [int]$Matches[3]
    if ($prefix -lt 16 -or $prefix -gt 32) { throw 'Prefix must be between /16 and /32.' }
    $bytes = ([System.Net.IPAddress]::Parse($Matches[1])).GetAddressBytes(); [array]::Reverse($bytes)
    $ip = [BitConverter]::ToUInt32($bytes, 0)
    $mask = if ($prefix -eq 0) { [uint32]0 } else { [uint32]([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefix)) }
    $network = $ip -band $mask
    $size = [uint32][math]::Pow(2, 32 - $prefix)
    $first = $network; $last = $network + $size - 1
    if ($prefix -le 30) { $first++; $last-- }
    for ($a = [uint64]$first; $a -le $last; $a++) {
        $b = [BitConverter]::GetBytes([uint32]$a); [array]::Reverse($b)
        ([System.Net.IPAddress]$b).ToString()
    }
}
