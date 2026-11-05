function Get-DiskReport {
    <#
    .SYNOPSIS
        Free space of every fixed disk, on one or many Windows computers, with a status.
    .EXAMPLE
        Get-DiskReport
    .EXAMPLE
        Get-DiskReport -ComputerName srv-files01, srv-sql01 -WarningPercent 20 | Where-Object Status -ne 'OK'
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('Name')]
        [string[]]$ComputerName = @('localhost'),
        [ValidateRange(1, 99)][int]$WarningPercent = 15,
        [ValidateRange(1, 99)][int]$CriticalPercent = 5
    )
    begin { Assert-Windows 'Get-DiskReport' }
    process {
        foreach ($c in $ComputerName) {
            try {
                foreach ($d in Get-CimOn -ComputerName $c -ClassName Win32_LogicalDisk -Filter 'DriveType=3') {
                    if (-not $d.Size) { continue }
                    $pct = [math]::Round(100 * $d.FreeSpace / $d.Size, 1)
                    [pscustomobject]@{
                        ComputerName = $(if (Test-IsLocalComputer $c) { $env:COMPUTERNAME } else { $c })
                        Drive = $d.DeviceID; Label = $d.VolumeName
                        SizeGB = [math]::Round($d.Size / 1GB, 1); FreeGB = [math]::Round($d.FreeSpace / 1GB, 1); FreePercent = $pct
                        Status = $(if ($pct -lt $CriticalPercent) { 'Critical' } elseif ($pct -lt $WarningPercent) { 'Warning' } else { 'OK' })
                    }
                }
            } catch { Write-Warning "${c}: $($_.Exception.Message)" }
        }
    }
}
