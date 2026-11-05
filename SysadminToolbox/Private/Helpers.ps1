function Test-IsLocalComputer {
    param([string]$ComputerName)
    $ComputerName -in @('', '.', 'localhost', '127.0.0.1', '::1', [System.Net.Dns]::GetHostName(), $env:COMPUTERNAME)
}

function Invoke-OnComputer {
    <# Runs a script block locally, or on a remote computer through PowerShell remoting. #>
    param(
        [string]$ComputerName,
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @(),
        [pscredential]$Credential
    )
    if (Test-IsLocalComputer $ComputerName) {
        return & $ScriptBlock @ArgumentList
    }
    $p = @{ ComputerName = $ComputerName; ScriptBlock = $ScriptBlock; ArgumentList = $ArgumentList; ErrorAction = 'Stop' }
    if ($Credential) { $p.Credential = $Credential }
    Invoke-Command @p
}

function Get-CimOn {
    <# Get-CimInstance locally (no WinRM needed) or on a remote computer. #>
    param([string]$ComputerName, [string]$ClassName, [string]$Filter)
    $p = @{ ClassName = $ClassName; ErrorAction = 'Stop' }
    if ($Filter) { $p.Filter = $Filter }
    if (-not (Test-IsLocalComputer $ComputerName)) { $p.ComputerName = $ComputerName }
    Get-CimInstance @p
}

function Assert-Windows {
    param([string]$Command)
    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
        throw "$Command needs Windows (it reads WMI/CIM, the registry or the event log)."
    }
}
