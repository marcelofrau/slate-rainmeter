param([string]$OutFile)

$ErrorActionPreference = 'SilentlyContinue'
. "$PSScriptRoot\load_env.ps1"

$adi = if ($env:AI_COST_CLI) { $env:AI_COST_CLI } else { "$env:USERPROFILE\Apps\bin\adi-aie.exe" }
if (-not (Test-Path $adi)) {
    $cmd = Get-Command adi-aie -ErrorAction SilentlyContinue
    if ($cmd) { $adi = $cmd.Source }
}

$finopsUrl = if ($env:FINOPS_DASHBOARD_URL) { $env:FINOPS_DASHBOARD_URL } else { 'https://finops.example.com/' }
$status = 'NO CLI'
$monthAmt = '--'
$dayAmt = '--'
$period = (Get-Date -Format 'yyyy-MM')

if (Test-Path $adi) {
    & $adi is-auth | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $status = 'SYNCED'
        $mOut = (& $adi user-cost --monthly 2>&1 | Out-String)
        if ($mOut -match '\$([0-9,]+\.[0-9]{2})') {
            $monthAmt = '$' + $Matches[1]
        }
        if ($mOut -match '\((\d{4}-\d{2})\)') {
            $period = $Matches[1]
        }
        $dOut = (& $adi user-cost --daily 2>&1 | Out-String)
        if ($dOut -match '\$([0-9,]+\.[0-9]{2})') {
            $dayAmt = '$' + $Matches[1]
        }
    } else {
        $status = 'AUTH REQ'
    }
}

# Fast pre-filtered current-month token breakdown by model family from ~/.claude/projects/*.jsonl
$pyCode = @'
import pathlib, json
from datetime import datetime
root = pathlib.Path.home() / '.claude' / 'projects'
rates = {'opus': (4.0, 20.0, 5.0, 0.20), 'sonnet': (2.0, 10.0, 2.5, 0.10), 'haiku': (0.10, 0.50, 0.125, 0.01)}
cost = {'opus': 0.0, 'sonnet': 0.0, 'haiku': 0.0}
turns = {'opus': 0, 'sonnet': 0, 'haiku': 0}
now = datetime.now()
cur_ym = now.strftime('%Y-%m')
month_start_ts = datetime(now.year, now.month, 1).timestamp()
if root.exists():
    for f in root.rglob('*.jsonl'):
        try:
            if f.stat().st_mtime < month_start_ts:
                continue
            with f.open('r', encoding='utf-8', errors='ignore') as fh:
                for line in fh:
                    if '"usage":' not in line: continue
                    obj = json.loads(line)
                    ts = obj.get('timestamp', '')
                    if ts and not ts.startswith(cur_ym): continue
                    msg = obj.get('message', {})
                    m = (msg.get('model') or obj.get('model') or '').lower()
                    u = msg.get('usage') or obj.get('usage') or {}
                    if not u or not m or m.startswith('<'): continue
                    t = 'opus' if 'opus' in m else ('sonnet' if 'sonnet' in m else ('haiku' if 'haiku' in m else None))
                    if not t: continue
                    ri, ro, rcw, rcr = rates[t]
                    c = ((int(u.get('input_tokens',0) or 0)*ri) + (int(u.get('output_tokens',0) or 0)*ro) + (int(u.get('cache_creation_input_tokens',0) or 0)*rcw) + (int(u.get('cache_read_input_tokens',0) or 0)*rcr)) / 1e6
                    cost[t] += c
                    turns[t] += 1
        except Exception:
            pass
tot = max(sum(cost.values()), 0.0001)
for k in ('opus', 'sonnet', 'haiku'):
    print(f'{k}_pct={cost[k]/tot*100:.1f}')
    print(f'{k}_turns={turns[k]}')
'@

$pyLines = $pyCode | python - 2>$null
$opusPct = '0.0'; $sonnetPct = '0.0'; $haikuPct = '0.0'
$opusTurns = '0'; $sonnetTurns = '0'; $haikuTurns = '0'
foreach ($l in $pyLines) {
    if ($l -match '^opus_pct=(.+)$')     { $opusPct = $Matches[1] }
    if ($l -match '^sonnet_pct=(.+)$')   { $sonnetPct = $Matches[1] }
    if ($l -match '^haiku_pct=(.+)$')    { $haikuPct = $Matches[1] }
    if ($l -match '^opus_turns=(.+)$')   { $opusTurns = $Matches[1] }
    if ($l -match '^sonnet_turns=(.+)$') { $sonnetTurns = $Matches[1] }
    if ($l -match '^haiku_turns=(.+)$')  { $haikuTurns = $Matches[1] }
}

$updated = Get-Date -Format 'HH:mm'
$lines = @(
    "status=$status",
    "month=$monthAmt",
    "day=$dayAmt",
    "period=$period",
    "opus_pct=$opusPct",
    "sonnet_pct=$sonnetPct",
    "haiku_pct=$haikuPct",
    "opus_turns=$opusTurns",
    "sonnet_turns=$sonnetTurns",
    "haiku_turns=$haikuTurns",
    "finops_url=$finopsUrl",
    "updated=$updated"
)
if ($OutFile) {
    $dir = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllLines($OutFile, $lines, [System.Text.UTF8Encoding]::new($false))
}
