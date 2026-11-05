@{
    RootModule        = 'SysadminToolbox.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '5f3b7a0e-8c1d-4f6a-9b2e-6d4c1a7e9f31'
    Author            = 'Enzo Marechal'
    CompanyName       = 'B2ZO0'
    Copyright         = '(c) 2026 Enzo Marechal. MIT license.'
    Description       = 'Everyday PowerShell tools for Windows admins: disks, uptime, pending reboots, services, local admins, event errors, ports, certificates, ping sweep, passwords and HTML reports.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport = @(
        'ConvertTo-ToolboxHtml', 'Get-CertificateExpiry', 'Get-DiskReport', 'Get-EventErrorSummary', 'Get-LocalAdminReport',
        'Get-PendingReboot', 'Get-ServiceHealth', 'Get-SubnetAddress', 'Get-UptimeReport', 'Invoke-PingSweep',
        'New-RandomPassword', 'Test-PortConnection'
    )
    AliasesToExport   = @('tpc')
    CmdletsToExport   = @()
    VariablesToExport = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('sysadmin', 'windows', 'monitoring', 'report', 'certificates', 'ports', 'active-directory', 'netcockpit')
            LicenseUri   = 'https://github.com/B2ZO0/sysadmin-toolbox/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/B2ZO0/sysadmin-toolbox'
        }
    }
}
