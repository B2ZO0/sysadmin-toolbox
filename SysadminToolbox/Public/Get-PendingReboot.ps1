function Get-PendingReboot {
    <#
    .SYNOPSIS
        Tells whether Windows computers are waiting for a reboot, and why.
    .DESCRIPTION
        Checks the usual places: Component Based Servicing, Windows Update, pending file
        rename operations, a pending computer rename and the SCCM client when present.
    .EXAMPLE
        Get-PendingReboot -ComputerName srv-app01, srv-app02 | Where-Object RebootPending
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('Name')]
        [string[]]$ComputerName = @('localhost'),
        [pscredential]$Credential
    )
    begin { Assert-Windows 'Get-PendingReboot' }
    process {
        foreach ($c in $ComputerName) {
            try {
                $r = Invoke-OnComputer -ComputerName $c -Credential $Credential -ScriptBlock {
                    $reasons = @()
                    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $reasons += 'Component servicing' }
                    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $reasons += 'Windows Update' }
                    $sm = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
                    if ($sm -and $sm.PSObject.Properties['PendingFileRenameOperations'] -and $sm.PendingFileRenameOperations) { $reasons += 'File rename' }
                    $active = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -ErrorAction SilentlyContinue).ComputerName
                    $pendingName = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -ErrorAction SilentlyContinue).ComputerName
                    if ($active -and $pendingName -and $active -ne $pendingName) { $reasons += 'Computer rename' }
                    try {
                        $ccm = Invoke-CimMethod -Namespace 'root\ccm\ClientSDK' -ClassName CCM_ClientUtilities -MethodName DetermineIfRebootPending -ErrorAction Stop
                        if ($ccm.RebootPending -or $ccm.IsHardRebootPending) { $reasons += 'SCCM client' }
                    } catch { Write-Verbose 'No SCCM client' }
                    [pscustomobject]@{ Name = $env:COMPUTERNAME; Reasons = $reasons }
                }
                [pscustomobject]@{ ComputerName = $r.Name; RebootPending = (@($r.Reasons).Count -gt 0); Reasons = (@($r.Reasons) -join ', ') }
            } catch { Write-Warning "${c}: $($_.Exception.Message)" }
        }
    }
}
