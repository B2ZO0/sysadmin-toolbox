function Get-LocalAdminReport {
    <#
    .SYNOPSIS
        Who is a member of the local Administrators group, on one or many Windows computers.
    .DESCRIPTION
        Uses the well-known SID S-1-5-32-544, so it works whatever the language of Windows
        (Administrateurs, Administradores...).
    .EXAMPLE
        Get-LocalAdminReport -ComputerName (Get-ADComputer -Filter *).Name | Export-Csv admins.csv -NoTypeInformation
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('Name')]
        [string[]]$ComputerName = @('localhost'),
        [pscredential]$Credential
    )
    begin { Assert-Windows 'Get-LocalAdminReport' }
    process {
        foreach ($c in $ComputerName) {
            try {
                Invoke-OnComputer -ComputerName $c -Credential $Credential -ScriptBlock {
                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$((New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')).Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]),group"
                    foreach ($m in @($group.Invoke('Members'))) {
                        $path = $m.GetType().InvokeMember('ADsPath', 'GetProperty', $null, $m, $null)
                        $class = $m.GetType().InvokeMember('Class', 'GetProperty', $null, $m, $null)
                        $parts = ($path -replace '^WinNT://', '').Split('/')
                        # WinNT://DOMAIN/PC/user = local account, WinNT://DOMAIN/user = domain account, WinNT://S-1-5-... = orphaned SID
                        $scope = if ($parts.Count -ge 3) { 'Local' } elseif ($parts.Count -eq 2) { 'Domain' } else { 'Orphaned SID' }
                        [pscustomobject]@{ ComputerName = $env:COMPUTERNAME; Member = $(if ($parts.Count -ge 2) { $parts[-2..-1] -join '\' } else { $parts[0] }); Type = $class; Scope = $scope }
                    }
                } | Select-Object ComputerName, Member, Type, Scope
            } catch { Write-Warning "${c}: $($_.Exception.Message)" }
        }
    }
}
