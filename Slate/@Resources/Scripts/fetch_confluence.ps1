param([string]$OutFile)

$ErrorActionPreference = 'SilentlyContinue'
. "$PSScriptRoot\load_env.ps1"

$baseUrl = if ($env:CONFLUENCE_URL) { $env:CONFLUENCE_URL.TrimEnd('/') } else { '' }
$token = $env:CONFLUENCE_PERSONAL_TOKEN
$status = 'NO TOKEN'
$count = '0'
$updated = Get-Date -Format 'HH:mm'
$lines = New-Object System.Collections.Generic.List[string]

if ($token -and $baseUrl) {
    try {
        $uri = "$baseUrl/rest/api/content/search?cql=type=page%20AND%20(contributor=currentUser()%20OR%20creator=currentUser())%20ORDER%20BY%20lastmodified%20DESC&limit=5&expand=space"
        $resp = Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 10
        $status = 'SYNCED'
        $count = [string](@($resp.results).Count)
        $idx = 1
        foreach ($p in $resp.results) {
            if ($idx -gt 5) { break }
            $id = [string]$p.id
            $t = ([string]$p.title) -replace '[\r\n]+',' '
            $sp = if ($p.space -and $p.space.key) { [string]$p.space.key } else { 'DOC' }
            $lines.Add("c${idx}_title=$t")
            $lines.Add("c${idx}_space=$sp")
            $lines.Add("c${idx}_url=$baseUrl/pages/viewpage.action?pageId=$id")
            $idx++
        }
        while ($idx -le 5) {
            $lines.Add("c${idx}_title=")
            $lines.Add("c${idx}_space=")
            $lines.Add("c${idx}_url=$baseUrl/")
            $idx++
        }
    } catch {
        $status = 'OFFLINE'
    }
}

$header = @(
    "status=$status",
    "base_url=$baseUrl/",
    "count=$count",
    "updated=$updated"
)
$all = $header + $lines
if ($OutFile) {
    $dir = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllLines($OutFile, $all, [System.Text.UTF8Encoding]::new($false))
}
