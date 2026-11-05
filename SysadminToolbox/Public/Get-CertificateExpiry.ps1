function Get-CertificateExpiry {
    <#
    .SYNOPSIS
        Reads the TLS certificate of websites and services and tells how many days are left.
    .DESCRIPTION
        Connects to each endpoint (host or host:port, default port 443), reads the certificate
        it presents, even if it is self-signed or expired, and returns its subject, issuer,
        expiry date and remaining days. Works on Windows, Linux and macOS.
    .EXAMPLE
        Get-CertificateExpiry intranet.corp.local, vcenter.corp.local, mail.example.com:993
    .EXAMPLE
        Get-Content endpoints.txt | Get-CertificateExpiry | Where-Object DaysLeft -lt 30
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Endpoint,
        [ValidateRange(100, 60000)][int]$TimeoutMs = 5000,
        [int]$WarningDays = 30
    )
    process {
        foreach ($e in $Endpoint) {
            $target = $e -replace '^https?://', '' -replace '/.*$', ''
            $hostName = $target; $port = 443
            if ($target -match '^\[(.+)\]:(\d+)$') { $hostName = $Matches[1]; $port = [int]$Matches[2] }
            elseif ($target -match '^([^:]+):(\d+)$') { $hostName = $Matches[1]; $port = [int]$Matches[2] }
            $client = New-Object System.Net.Sockets.TcpClient
            try {
                if (-not $client.ConnectAsync($hostName, $port).Wait($TimeoutMs)) { throw "no answer within $TimeoutMs ms" }
                $callback = [System.Net.Security.RemoteCertificateValidationCallback] { param($s, $c, $ch, $err) $true }
                $ssl = New-Object System.Net.Security.SslStream($client.GetStream(), $false, $callback)
                $ssl.ReadTimeout = $TimeoutMs
                $ssl.AuthenticateAsClient($hostName)
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)
                $days = [int][math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)
                $status = if ($days -lt 0) { 'Expired' } elseif ($days -lt $WarningDays) { 'Expiring' } else { 'OK' }
                $ssl.Dispose()
                [pscustomobject]@{
                    Endpoint = "${hostName}:$port"; Status = $status; DaysLeft = $days; NotAfter = $cert.NotAfter
                    Subject = $cert.Subject; Issuer = $cert.Issuer; SelfSigned = ($cert.Subject -eq $cert.Issuer)
                    Thumbprint = $cert.Thumbprint
                }
            } catch {
                $ex = $_.Exception
                while ($ex.InnerException) { $ex = $ex.InnerException }
                $msg = $ex.Message
                [pscustomobject]@{ Endpoint = "${hostName}:$port"; Status = 'Error'; DaysLeft = $null; NotAfter = $null
                    Subject = $msg; Issuer = $null; SelfSigned = $null; Thumbprint = $null }
            } finally { $client.Dispose() }
        }
    }
}
