function Get-UptimeReport {
    <#
    .SYNOPSIS
        Last boot time, uptime, OS and pending reboot of Windows computers.
    .EXAMPLE
        Get-UptimeReport -ComputerName (Get-ADComputer -Filter 'OperatingSystem -like "*Server*"').Name
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('Name')]
        [string[]]$ComputerName = @('localhost'),
        [pscredential]$Credential
    )
    begin { Assert-Windows 'Get-UptimeReport' }
    process {
        foreach ($c in $ComputerName) {
            try {
                $os = Get-CimOn -ComputerName $c -ClassName Win32_OperatingSystem
                $up = (Get-Date) - $os.LastBootUpTime
                $pending = (Get-PendingReboot -ComputerName $c -Credential $Credential).RebootPending
                [pscustomobject]@{
                    ComputerName = $os.CSName; OS = $os.Caption; Version = $os.Version
                    LastBoot = $os.LastBootUpTime; UptimeDays = [math]::Round($up.TotalDays, 1); RebootPending = $pending
                }
            } catch { Write-Warning "${c}: $($_.Exception.Message)" }
        }
    }
}
