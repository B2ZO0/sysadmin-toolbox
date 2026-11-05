function Get-EventErrorSummary {
    <#
    .SYNOPSIS
        The errors that came back most often in the System and Application logs, grouped.
    .EXAMPLE
        Get-EventErrorSummary -Hours 24
    .EXAMPLE
        Get-EventErrorSummary -ComputerName srv-sql01 -Hours 72 -IncludeWarnings | Select-Object -First 10
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][Alias('Name')]
        [string[]]$ComputerName = @('localhost'),
        [ValidateRange(1, 8760)][int]$Hours = 24,
        [string[]]$LogName = @('System', 'Application'),
        [switch]$IncludeWarnings
    )
    begin { Assert-Windows 'Get-EventErrorSummary' }
    process {
        foreach ($c in $ComputerName) {
            $levels = @(1, 2); if ($IncludeWarnings) { $levels += 3 }
            $filter = @{ LogName = $LogName; Level = $levels; StartTime = (Get-Date).AddHours(-$Hours) }
            $p = @{ FilterHashtable = $filter; ErrorAction = 'Stop' }
            if (-not (Test-IsLocalComputer $c)) { $p.ComputerName = $c }
            try { $events = @(Get-WinEvent @p) }
            catch {
                if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound') { continue }
                Write-Warning "${c}: $($_.Exception.Message)"; continue
            }
            $events | Group-Object LogName, ProviderName, Id | Sort-Object Count -Descending | ForEach-Object {
                $last = $_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1
                $msg = if ($last.Message) { ($last.Message -split "`r?`n")[0] } else { '' }
                if ($msg.Length -gt 160) { $msg = $msg.Substring(0, 157) + '...' }
                [pscustomobject]@{ ComputerName = $last.MachineName; Log = $last.LogName; Source = $last.ProviderName; EventId = $last.Id
                    Level = $last.LevelDisplayName; Count = $_.Count; LastSeen = $last.TimeCreated; Message = $msg }
            }
        }
    }
}
