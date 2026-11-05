# Shared by Get-WakeReport and Disable-AutoWake: runs on the target computer.
$script:WakeScanBlock = {
    param([int]$Days, [bool]$Fix)
    $pwrKey   = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
    $crashKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'
    $maintKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance'
    function Get-Val($key, $name) {
        try { (Get-ItemProperty -Path $key -Name $name -ErrorAction Stop).$name } catch { $null }
    }
    function Get-Armed {
        # devices allowed to wake the computer (network card, mouse, keyboard); "NONE" / "AUCUN" when empty
        @(powercfg /devicequery wake_armed 2>$null | Where-Object { $_ -and $_.Trim() -and $_ -notmatch '^(NONE|AUCUN|KEINE|NINGUNO)$' })
    }
    function Get-State {
        [ordered]@{
            FastStartup     = ((Get-Val $pwrKey 'HiberbootEnabled') -ne 0)            # absent = enabled by default
            RebootOnCrash   = ((Get-Val $crashKey 'AutoReboot') -ne 0)
            MaintenanceWake = ((Get-Val $maintKey 'WakeUp') -ne 0)
            WakeDevices     = Get-Armed
            WakeTasks       = @(Get-ScheduledTask -ErrorAction SilentlyContinue |
                                Where-Object { $_.Settings.WakeToRun -and $_.State -ne 'Disabled' } |
                                ForEach-Object { ($_.TaskPath + $_.TaskName) })
        }
    }

    $before = Get-State
    $lastWake = ((powercfg /lastwake 2>$null) | Out-String).Trim()
    $timers = ((powercfg /waketimers 2>$null) | Out-String).Trim()
    # 1074 = who asked for the shutdown/restart (Windows Update, a user, a program)
    # 41 = unexpected shutdown (crash, power cut), 1 (Power-Troubleshooter) = what woke the computer
    $events = @(Get-WinEvent -FilterHashtable @{
            LogName = 'System'; Id = 1074, 41, 1; StartTime = (Get-Date).AddDays(-$Days)
            ProviderName = 'User32', 'Microsoft-Windows-Kernel-Power', 'Microsoft-Windows-Power-Troubleshooter'
        } -MaxEvents 30 -ErrorAction SilentlyContinue | ForEach-Object {
            $m = ($_.Message -replace '\s+', ' ').Trim()
            [pscustomobject]@{ Time = $_.TimeCreated; Id = $_.Id
                Kind = switch ($_.Id) { 1074 { 'Shutdown/restart requested' } 41 { 'Unexpected shutdown' } default { 'Wake' } }
                Message = $m.Substring(0, [Math]::Min(220, $m.Length)) }
        })

    $applied = @()
    if ($Fix) {
        Set-ItemProperty -Path $pwrKey -Name HiberbootEnabled -Value 0 -Type DWord; $applied += 'Fast startup off'
        Set-ItemProperty -Path $crashKey -Name AutoReboot -Value 0 -Type DWord; $applied += 'No automatic restart after a crash'
        if (-not (Test-Path $maintKey)) { New-Item -Path $maintKey -Force | Out-Null }
        Set-ItemProperty -Path $maintKey -Name WakeUp -Value 0 -Type DWord; $applied += 'Automatic maintenance no longer wakes the computer'
        powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP RTCWAKE 0 | Out-Null
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP RTCWAKE 0 | Out-Null
        powercfg /setactive SCHEME_CURRENT | Out-Null; $applied += 'Wake timers off (mains and battery)'
        # Only the right to wake the computer is removed: the network card keeps working.
        foreach ($d in $before.WakeDevices) { powercfg /devicedisablewake "$d" | Out-Null }
        if ($before.WakeDevices.Count) { $applied += "Wake disabled for $($before.WakeDevices.Count) device(s)" }
    }
    $after = if ($Fix) { Get-State } else { $before }

    $causes = @()
    if ($before.FastStartup) { $causes += 'Fast startup is on: "shut down" is a hibernation, so the computer can be woken' }
    if ($before.RebootOnCrash) { $causes += 'Restart after a crash is on: a crash during shutdown turns the computer back on' }
    if ($before.MaintenanceWake) { $causes += 'Automatic maintenance may wake the computer at night' }
    if ($before.WakeDevices.Count) { $causes += "$($before.WakeDevices.Count) device(s) can wake the computer: $($before.WakeDevices -join ', ')" }
    if ($before.WakeTasks.Count) { $causes += "$($before.WakeTasks.Count) scheduled task(s) may wake the computer: $(($before.WakeTasks | Select-Object -First 5) -join ', ')" }
    if ($events | Where-Object Id -eq 41) { $causes += 'Unexpected shutdowns were logged (crash or power cut): check the BIOS "restore on AC power loss" setting' }

    [pscustomobject]@{
        ComputerName    = $env:COMPUTERNAME
        FastStartup     = $after.FastStartup
        RebootOnCrash   = $after.RebootOnCrash
        MaintenanceWake = $after.MaintenanceWake
        WakeDevices     = ($after.WakeDevices -join ', ')
        WakeTasks       = $after.WakeTasks.Count
        LikelyCauses    = $causes
        LastWake        = $lastWake
        WakeTimers      = $timers
        Events          = $events
        Applied         = $applied
    }
}
