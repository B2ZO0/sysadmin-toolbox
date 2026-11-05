function Disable-AutoWake {
    <#
    .SYNOPSIS
        Stops Windows computers from turning back on by themselves after a shutdown. Silent for the user.
    .DESCRIPTION
        Applies, locally or remotely, the fixes for the causes found by Get-WakeReport:
          1. fast startup off, so "shut down" really shuts down;
          2. no automatic restart after a crash;
          3. automatic maintenance no longer wakes the computer;
          4. wake timers off (mains and battery);
          5. no device (network card, mouse, keyboard) may wake the computer.
             The network card keeps working: only its right to wake the computer is removed.
        No window, no restart: the changes take effect at the next shutdown.
        Not covered (check them in the BIOS/UEFI if computers still turn on): "Wake on LAN",
        "Power on by RTC/alarm" and "Restore on AC power loss".
        Supports -WhatIf and -Confirm. Needs an administrator account on the target computers.
    .EXAMPLE
        Disable-AutoWake -ComputerName PC-012 -WhatIf
    .EXAMPLE
        Disable-AutoWake -ComputerName PC-012, PC-013 | Format-List ComputerName, Applied, LikelyCauses
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('Name')]
        [string[]]$ComputerName = @('localhost'),
        [pscredential]$Credential
    )
    begin { Assert-Windows 'Disable-AutoWake' }
    process {
        foreach ($c in $ComputerName) {
            if (-not $PSCmdlet.ShouldProcess($c, 'Disable fast startup, restart after crash, maintenance wake, wake timers and device wake')) { continue }
            try { Invoke-OnComputer -ComputerName $c -Credential $Credential -ScriptBlock $script:WakeScanBlock -ArgumentList 7, $true |
                      Select-Object * -ExcludeProperty PSComputerName, RunspaceId, PSShowComputerName }
            catch { Write-Warning "${c}: $($_.Exception.Message)" }
        }
    }
}
