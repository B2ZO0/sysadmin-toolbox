# SysadminToolbox: everyday PowerShell tools for Windows admins.
foreach ($folder in 'Private', 'Public') {
    foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot $folder) -Filter *.ps1 -ErrorAction SilentlyContinue) {
        . $file.FullName
    }
}
Set-Alias -Name tpc -Value Test-PortConnection
$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter *.ps1 | ForEach-Object BaseName) + 'Get-SubnetAddress'
Export-ModuleMember -Function $public -Alias tpc
