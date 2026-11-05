function Get-WakeReport {
    <#
    .SYNOPSIS
        Why do these Windows computers turn back on by themselves? Diagnoses it, without changing anything.
    .DESCRIPTION
        Users say their computer was switched off in the evening and is on again in the morning, but
        nothing shows on your side. Get-WakeReport collects, locally or remotely, everything that can
        turn a computer back on and lists the likely causes:
          - fast startup (a "shutdown" that is really a hibernation),
          - automatic restart after a crash (a crash during shutdown restarts the computer),
          - automatic maintenance allowed to wake the computer,
          - wake timers and devices allowed to wake it (network card, mouse, keyboard),
          - scheduled tasks set to wake the computer,
          - the last wake source and the shutdown, crash and wake events of the last days.
        To apply the fixes, use Disable-AutoWake.
    .EXAMPLE
        Get-WakeReport -ComputerName PC-ACCOUNTING-01, PC-ACCOUNTING-02
    .EXAMPLE
        Get-WakeReport PC-012 -Days 14 | Select-Object -ExpandProperty Events | Format-Table
    .EXAMPLE
        Get-WakeReport -ComputerName (Get-ADComputer -Filter * -SearchBase 'OU=Workshop,DC=corp,DC=example').Name |
            Select-Object ComputerName, FastStartup, RebootOnCrash, WakeDevices, WakeTasks | ConvertTo-ToolboxHtml -Title 'Auto wake' -Path wake.html
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('Name')]
        [string[]]$ComputerName = @('localhost'),
        [ValidateRange(1, 90)][int]$Days = 7,
        [pscredential]$Credential
    )
    begin { Assert-Windows 'Get-WakeReport' }
    process {
        foreach ($c in $ComputerName) {
            try { Invoke-OnComputer -ComputerName $c -Credential $Credential -ScriptBlock $script:WakeScanBlock -ArgumentList $Days, $false |
                      Select-Object * -ExcludeProperty Applied, PSComputerName, RunspaceId, PSShowComputerName }
            catch { Write-Warning "${c}: $($_.Exception.Message)" }
        }
    }
}
