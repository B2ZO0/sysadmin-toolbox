function ConvertTo-ToolboxHtml {
    <#
    .SYNOPSIS
        Turns the output of any command into a clean, self-contained HTML report.
    .DESCRIPTION
        Rows whose Status is Critical, Error, Expired, Closed or Down are highlighted in red,
        Warning, Expiring or Filtered in orange. Light and dark themes, sortable columns,
        no external resource: the file can be sent by mail as it is.
    .EXAMPLE
        Get-DiskReport -ComputerName srv01, srv02 | ConvertTo-ToolboxHtml -Title 'Disk space' -Path disks.html
    .EXAMPLE
        Get-CertificateExpiry (Get-Content sites.txt) | ConvertTo-ToolboxHtml -Title 'Certificates' -Path certs.html -Open
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][object]$InputObject,
        [string]$Title = 'Report',
        [string]$Path,
        [switch]$Open
    )
    begin { $rows = New-Object System.Collections.Generic.List[object] }
    process { $rows.Add($InputObject) }
    end {
        $enc = { param($v) if ($null -eq $v) { '' } elseif ($v -is [datetime]) { $v.ToString('yyyy-MM-dd HH:mm') } else { [System.Net.WebUtility]::HtmlEncode([string]$v) } }
        $cols = @()
        if ($rows.Count) { $cols = @($rows[0].PSObject.Properties | ForEach-Object Name) }
        $head = ($cols | ForEach-Object { "<th onclick='sortBy(this)'>$(& $enc $_)</th>" }) -join ''
        $body = foreach ($r in $rows) {
            $st = if ($r.PSObject.Properties['Status']) { [string]$r.Status } else { '' }
            $cls = if ($st -match '^(Critical|Error|Expired|Closed|Down|Failed)$') { 'bad' } elseif ($st -match '^(Warning|Expiring|Filtered)$') { 'warn' } else { '' }
            "<tr class='$cls'>" + (($cols | ForEach-Object { $v = $r.$_; "<td>$(& $enc $v)</td>" }) -join '') + '</tr>'
        }
        $bad = @($rows | Where-Object { $_.PSObject.Properties['Status'] -and [string]$_.Status -match '^(Critical|Error|Expired|Closed|Down|Failed)$' }).Count
        $warn = @($rows | Where-Object { $_.PSObject.Properties['Status'] -and [string]$_.Status -match '^(Warning|Expiring|Filtered)$' }).Count
        $html = @"
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(& $enc $Title)</title><style>
:root{--bg:#0c0e16;--panel:#141725;--line:#262a3d;--text:#e8e9f3;--muted:#9096b4;--accent:#8a6cff;--bad:#ff5c7a;--warn:#f5b13d;--ok:#35d07f}
@media (prefers-color-scheme: light){:root{--bg:#f6f6fb;--panel:#fff;--line:#e3e4ef;--text:#171a2b;--muted:#5d6382;--accent:#6d4cf0;--bad:#d6264a;--warn:#c27c00;--ok:#14a35b}}
body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 "Segoe UI",system-ui,sans-serif}.wrap{max-width:1200px;margin:0 auto;padding:28px 24px}
h1{margin:0 0 4px;font-size:22px}.sub{color:var(--muted);margin-bottom:18px}.pill{display:inline-block;padding:2px 10px;border-radius:999px;margin-left:6px;font-size:12px;font-weight:600}
.pill.bad{background:var(--bad);color:#fff}.pill.warn{background:var(--warn);color:#1b1300}.pill.ok{background:var(--ok);color:#03130a}
.card{background:var(--panel);border:1px solid var(--line);border-radius:14px;overflow:auto}table{width:100%;border-collapse:collapse}
th{text-align:left;color:var(--muted);font-weight:600;padding:9px 12px;border-bottom:1px solid var(--line);cursor:pointer;white-space:nowrap}th:hover{color:var(--accent)}
td{padding:8px 12px;border-bottom:1px solid var(--line)}tr.bad td{background:color-mix(in srgb,var(--bad) 13%,transparent)}tr.warn td{background:color-mix(in srgb,var(--warn) 13%,transparent)}
footer{color:var(--muted);font-size:12px;margin-top:16px}footer a{color:var(--accent)}
</style></head><body><div class="wrap"><h1>$(& $enc $Title)</h1>
<div class="sub">$(Get-Date -Format 'yyyy-MM-dd HH:mm') · $($rows.Count) row(s)$(if ($bad) { "<span class='pill bad'>$bad to fix</span>" })$(if ($warn) { "<span class='pill warn'>$warn to watch</span>" })$(if (-not $bad -and -not $warn) { "<span class='pill ok'>all good</span>" })</div>
<div class="card"><table><thead><tr>$head</tr></thead><tbody>$($body -join "`n")</tbody></table></div>
<footer>Generated with <a href="https://github.com/B2ZO0/sysadmin-toolbox">sysadmin-toolbox</a></footer></div>
<script>function sortBy(th){var t=th.closest('table'),i=[].indexOf.call(th.parentNode.children,th),b=t.tBodies[0],asc=th.dataset.asc!=='1';
[].slice.call(b.rows).sort(function(x,y){var a=x.cells[i].innerText,c=y.cells[i].innerText,n=parseFloat(a)-parseFloat(c);return (isNaN(n)?a.localeCompare(c):n)*(asc?1:-1)}).forEach(function(r){b.appendChild(r)});th.dataset.asc=asc?'1':'0'}</script>
</body></html>
"@
        if ($Path) {
            $html | Out-File -FilePath $Path -Encoding utf8
            if ($Open) { Invoke-Item $Path }
            Get-Item $Path
        } else { $html }
    }
}
