function Test-PortConnection {
    <#
    .SYNOPSIS
        Tests TCP ports on one or more hosts, fast, with a timeout.
    .DESCRIPTION
        Opens a TCP connection to each host and port and reports Open, Closed (refused) or
        Filtered (no answer before the timeout). Works on Windows, Linux and macOS.
        Windows retries a refused connection for about two seconds before giving up, hence
        the 3-second default: lower it only for hosts you know answer quickly.
    .EXAMPLE
        Test-PortConnection -ComputerName srv-files01, srv-sql01 -Port 445, 1433, 3389
    .EXAMPLE
        'dc01', 'dc02' | Test-PortConnection -Port 53, 88, 389, 636 | Where-Object Status -ne 'Open'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'Host', 'IPAddress')]
        [string[]]$ComputerName,
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)][int[]]$Port,
        [ValidateRange(50, 60000)][int]$TimeoutMs = 3000
    )
    process {
        foreach ($c in $ComputerName) {
            $pending = foreach ($p in $Port) {
                $client = New-Object System.Net.Sockets.TcpClient
                [pscustomobject]@{ Port = $p; Client = $client; Task = $client.ConnectAsync($c, $p); Start = [datetime]::UtcNow }
            }
            foreach ($t in $pending) {
                $status = 'Filtered'; $ms = $null
                try {
                    $left = [math]::Max(1, $TimeoutMs - [int]([datetime]::UtcNow - $t.Start).TotalMilliseconds)
                    if ($t.Task.Wait($left)) {
                        $status = 'Open'; $ms = [int]([datetime]::UtcNow - $t.Start).TotalMilliseconds
                    }
                } catch {
                    $inner = $_.Exception.InnerException
                    while ($inner -and $inner.InnerException) { $inner = $inner.InnerException }
                    if ($inner -is [System.Net.Sockets.SocketException] -and $inner.SocketErrorCode -eq 'ConnectionRefused') { $status = 'Closed' }
                    elseif ($inner -is [System.Net.Sockets.SocketException] -and $inner.SocketErrorCode -eq 'HostNotFound') { $status = 'Unknown host' }
                } finally { $t.Client.Dispose() }
                [pscustomobject]@{ ComputerName = $c; Port = $t.Port; Status = $status; LatencyMs = $ms }
            }
        }
    }
}
