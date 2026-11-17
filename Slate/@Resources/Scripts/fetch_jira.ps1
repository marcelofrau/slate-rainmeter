param([string]$OutFile)

$ErrorActionPreference = 'SilentlyContinue'
. "$PSScriptRoot\load_env.ps1"

$baseUrl = if ($env:JIRA_URL) { $env:JIRA_URL.TrimEnd('/') } else { '' }
$token = $env:JIRA_PERSONAL_TOKEN
$status = 'NO TOKEN'
$total = '0'
$updated = Get-Date -Format 'HH:mm'
$lines = New-Object System.Collections.Generic.List[string]

if ($token -and $baseUrl) {
    try {
        $uri = "$baseUrl/rest/api/2/search?jql=assignee=currentUser()%20AND%20resolution=Unresolved%20ORDER%20BY%20updated%20DESC&maxResults=5&fields=key,summary,status"
        $resp = Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 10
        $status = 'SYNCED'
        $total = [string]($resp.total ?? 0)
        $idx = 1
        foreach ($it in $resp.issues) {
            if ($idx -gt 5) { break }
            $k = [string]$it.key
            $s = ([string]$it.fields.summary) -replace '[\r\n]+',' '
            $st = ([string]$it.fields.status.name).ToUpperInvariant()
            if ($st -eq 'IN PROGRESS') { $st = 'IN PROG' }
            elseif ($st -eq 'IN REVIEW') { $st = 'REVIEW' }
            $lines.Add("j${idx}_key=$k")
            $lines.Add("j${idx}_sum=$s")
            $lines.Add("j${idx}_status=$st")
            $lines.Add("j${idx}_url=$baseUrl/browse/$k")
            $idx++
        }
        while ($idx -le 5) {
            $lines.Add("j${idx}_key=")
            $lines.Add("j${idx}_sum=")
            $lines.Add("j${idx}_status=")
            $lines.Add("j${idx}_url=$baseUrl/")
            $idx++
        }
    } catch {
        $status = 'OFFLINE'
    }
}

$header = @(
    "status=$status",
    "base_url=$baseUrl/",
    "total=$total",
    "updated=$updated"
)
$all = $header + $lines
if ($OutFile) {
    $dir = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllLines($OutFile, $all, [System.Text.UTF8Encoding]::new($false))
}
