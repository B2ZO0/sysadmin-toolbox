function Get-ServiceHealth {
    <#
    .SYNOPSIS
        Services set to start automatically that are not running: the first thing to check after a reboot.
    .DESCRIPTION
        Services that normally stop by themselves (delayed or trigger-start updaters, for example)
        are ignored. Add your own with -Exclude.
    .EXAMPLE
        Get-ServiceHealth -ComputerName srv-app01, srv-app02
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('Name')]
        [string[]]$ComputerName = @('localhost'),
        [string[]]$Exclude = @()
    )
    begin {
        Assert-Windows 'Get-ServiceHealth'
        $known = 'gupdate', 'gupdatem', 'edgeupdate', 'edgeupdatem', 'MapsBroker', 'RemoteRegistry', 'sppsvc', 'wuauserv', 'BITS',
                 'TrustedInstaller', 'ShellHWDetection', 'CDPSvc', 'tiledatamodelsvc', 'WbioSrvc', 'DoSvc', 'UsoSvc', 'MSDTC',
                 'clr_optimization_*', 'GoogleUpdater*', 'OneSyncSvc*', 'CDPUserSvc*', 'WpnUserService*', 'sppsvc', 'RasMan'
    }
    process {
        foreach ($c in $ComputerName) {
            try {
                foreach ($s in Get-CimOn -ComputerName $c -ClassName Win32_Service -Filter "StartMode='Auto' AND State<>'Running'") {
                    $skip = $false
                    foreach ($pattern in $known + $Exclude) { if ($s.Name -like $pattern) { $skip = $true; break } }
                    if ($skip) { continue }
                    [pscustomobject]@{ ComputerName = $s.SystemName; Name = $s.Name; DisplayName = $s.DisplayName; State = $s.State
                        ExitCode = $s.ExitCode; Account = $s.StartName }
                }
            } catch { Write-Warning "${c}: $($_.Exception.Message)" }
        }
    }
}
