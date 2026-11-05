BeforeAll {
    Import-Module (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'SysadminToolbox') 'SysadminToolbox.psd1') -Force
    $script:OnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
}

Describe 'Module' {
    It 'exports the 14 commands and the tpc alias' {
        (Get-Command -Module SysadminToolbox -CommandType Function).Count | Should -Be 14
        (Get-Alias tpc).ResolvedCommandName | Should -Be 'Test-PortConnection'
    }
    It 'has help for every command' {
        foreach ($c in Get-Command -Module SysadminToolbox -CommandType Function) {
            (Get-Help $c.Name).Synopsis | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'New-RandomPassword' {
    It 'mixes every character class at the requested length' {
        foreach ($p in New-RandomPassword -Length 24 -Count 50) {
            $p.Length | Should -Be 24
            $p | Should -MatchExactly '[a-z]'
            $p | Should -MatchExactly '[A-Z]'
            $p | Should -Match '[0-9]'
            $p | Should -Match '[^A-Za-z0-9]'
            $p | Should -Not -MatchExactly '[0O1lI]'
        }
    }
    It 'can leave symbols out' {
        New-RandomPassword -Length 30 -NoSymbols | Should -Match '^[A-Za-z0-9]{30}$'
    }
    It 'makes passphrases' {
        New-RandomPassword -Passphrase -Words 5 | Should -Match '^([A-Z][a-z]+-){5}\d{1,2}$'
    }
    It 'returns a SecureString on request' {
        New-RandomPassword -AsSecureString | Should -BeOfType [securestring]
    }
    It 'does not repeat itself' {
        (New-RandomPassword -Count 200 | Select-Object -Unique).Count | Should -Be 200
    }
}

Describe 'Get-SubnetAddress' {
    It 'lists usable hosts' {
        @(Get-SubnetAddress 192.0.2.0/24).Count | Should -Be 254
        Get-SubnetAddress 192.0.2.4/30 | Should -Be @('192.0.2.5', '192.0.2.6')
        Get-SubnetAddress 192.0.2.9/32 | Should -Be '192.0.2.9'
    }
    It 'refuses invalid input' {
        { Get-SubnetAddress 192.0.2.0 } | Should -Throw
        { Get-SubnetAddress 10.0.0.0/8 } | Should -Throw
    }
}

Describe 'Test-PortConnection' {
    BeforeAll {
        $script:listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $script:listener.Start()
        $script:openPort = $script:listener.LocalEndpoint.Port
    }
    AfterAll { $script:listener.Stop() }
    It 'sees an open port' {
        (Test-PortConnection -ComputerName 127.0.0.1 -Port $script:openPort).Status | Should -Be 'Open'
    }
    It 'sees a closed port' {
        $s = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0); $s.Start(); $p = $s.LocalEndpoint.Port; $s.Stop()
        (Test-PortConnection -ComputerName 127.0.0.1 -Port $p -TimeoutMs 6000).Status | Should -Be 'Closed'
    }
    It 'takes computers from the pipeline' {
        @('127.0.0.1', 'localhost' | Test-PortConnection -Port $script:openPort).Count | Should -Be 2
    }
}

Describe 'Get-CertificateExpiry' {
    It 'reports an unreachable endpoint as an error instead of failing' {
        $r = Get-CertificateExpiry 'host.invalid:443' -TimeoutMs 2000
        $r.Status | Should -Be 'Error'
        $r.Endpoint | Should -Be 'host.invalid:443'
    }
}

Describe 'ConvertTo-ToolboxHtml' {
    It 'highlights problems and escapes content' {
        $html = @(
            [pscustomobject]@{ Name = 'a<b>'; Status = 'OK' }
            [pscustomobject]@{ Name = 'disk'; Status = 'Critical' }
            [pscustomobject]@{ Name = 'cert'; Status = 'Expiring' }
        ) | ConvertTo-ToolboxHtml -Title 'Test report'
        $html | Should -Match '<title>Test report</title>'
        $html | Should -Match "class='bad'"
        $html | Should -Match "class='warn'"
        $html | Should -Match 'a&lt;b&gt;'
        $html | Should -Match '1 to fix'
    }
}

Describe 'Windows commands' -Skip:(-not (($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows)) {
    It 'Get-DiskReport reads the system drive' {
        $d = Get-DiskReport | Where-Object Drive -eq $env:SystemDrive
        $d.SizeGB | Should -BeGreaterThan 0
        $d.Status | Should -BeIn @('OK', 'Warning', 'Critical')
    }
    It 'Get-UptimeReport and Get-PendingReboot answer for this computer' {
        (Get-UptimeReport).ComputerName | Should -Be $env:COMPUTERNAME
        (Get-PendingReboot).RebootPending | Should -BeOfType [bool]
    }
    It 'Get-LocalAdminReport lists the local administrators' {
        @(Get-LocalAdminReport).Count | Should -BeGreaterThan 0
    }
    It 'Get-ServiceHealth and Get-EventErrorSummary run' {
        { Get-ServiceHealth -WarningAction Stop } | Should -Not -Throw
        { Get-EventErrorSummary -Hours 2 -WarningAction Stop } | Should -Not -Throw
    }
    It 'Get-WakeReport diagnoses this computer without changing it' {
        $r = Get-WakeReport -Days 2
        $r.ComputerName | Should -Be $env:COMPUTERNAME
        $r.PSObject.Properties.Name | Should -Contain 'LikelyCauses'
        $r.PSObject.Properties.Name | Should -Not -Contain 'Applied'
    }
    It 'Disable-AutoWake -WhatIf changes nothing' {
        $before = (Get-WakeReport -Days 1).RebootOnCrash
        Disable-AutoWake -WhatIf | Should -BeNullOrEmpty
        (Get-WakeReport -Days 1).RebootOnCrash | Should -Be $before
    }
    It 'Disable-AutoWake applies the fixes' {
        $r = Disable-AutoWake -Confirm:$false
        $r.Applied | Should -Contain 'Fast startup off'
        $r.FastStartup | Should -BeFalse
        $r.RebootOnCrash | Should -BeFalse
        $r.MaintenanceWake | Should -BeFalse
    }
    It 'Invoke-PingSweep finds this computer' {
        (Invoke-PingSweep 127.0.0.1/32).Status | Should -Be 'Up'
    }
}

Describe 'Windows commands on other systems' -Skip:(($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows) {
    It 'explains that Windows is needed' {
        { Get-DiskReport } | Should -Throw '*needs Windows*'
    }
}
