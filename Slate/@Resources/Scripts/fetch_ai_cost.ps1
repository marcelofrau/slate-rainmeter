param([string]$OutFile)

$ErrorActionPreference = 'SilentlyContinue'
. "$PSScriptRoot\load_env.ps1"

$finopsUrl = if ($env:FINOPS_DASHBOARD_URL) { $env:FINOPS_DASHBOARD_URL } else { 'https://finops.example.com/' }

# 1. Pure-local, zero-browser calculation from ~/.claude/projects/*.jsonl
# Deduplicates streaming chunks by message.id and applies Lakehouse rates:
# Opus ($4/$20, cache_write $5.0, cache_read $0.40), Sonnet ($2/$10, cw $2.5, cr $0.20), Haiku ($0.1/$0.5, cw $0.125, cr $0.01)
$pyCode = @'
import pathlib, json
from datetime import datetime, timezone

root = pathlib.Path.home() / '.claude' / 'projects'
rates = {
    'opus':   (4.0, 20.0, 5.0,   0.40),
    'sonnet': (2.0, 10.0, 2.5,   0.20),
    'haiku':  (0.10, 0.50, 0.125, 0.01)
}
cost_m = {'opus': 0.0, 'sonnet': 0.0, 'haiku': 0.0}
cost_d = 0.0
turns = {'opus': 0, 'sonnet': 0, 'haiku': 0}
seen_ids = set()

now = datetime.now()
cur_ym = now.strftime('%Y-%m')
cur_ymd = now.strftime('%Y-%m-%d')
month_start_ts = datetime(now.year, now.month, 1).timestamp()

if root.exists():
    for f in root.rglob('*.jsonl'):
        try:
            if f.stat().st_mtime < month_start_ts:
                continue
            with f.open('r', encoding='utf-8', errors='ignore') as fh:
                for line in fh:
                    if '"usage":' not in line:
                        continue
                    obj = json.loads(line)
                    ts = obj.get('timestamp', '')
                    if ts and not ts.startswith(cur_ym):
                        continue
                    msg = obj.get('message', {})
                    m = (msg.get('model') or obj.get('model') or '').lower()
                    u = msg.get('usage') or obj.get('usage') or {}
                    if not u or not m or m.startswith('<'):
                        continue
                    t = 'opus' if 'opus' in m else ('sonnet' if 'sonnet' in m else ('haiku' if 'haiku' in m else None))
                    if not t:
                        continue
                    mid = msg.get('id') or obj.get('requestId') or obj.get('uuid')
                    if mid:
                        if mid in seen_ids:
                            continue
                        seen_ids.add(mid)
                    ri, ro, rcw, rcr = rates[t]
                    c = (
                        (int(u.get('input_tokens', 0) or 0) * ri) +
                        (int(u.get('output_tokens', 0) or 0) * ro) +
                        (int(u.get('cache_creation_input_tokens', 0) or 0) * rcw) +
                        (int(u.get('cache_read_input_tokens', 0) or 0) * rcr)
                    ) / 1e6
                    cost_m[t] += c
                    turns[t] += 1
                    if ts.startswith(cur_ymd):
                        cost_d += c
        except Exception:
            pass

# Also check if ~/.aws/cli/cache has a non-expired SSO role credential (strictly read-only, never invokes aws sso login)
aws_valid = False
cli_cache = pathlib.Path.home() / '.aws' / 'cli' / 'cache'
now_utc = datetime.now(timezone.utc)
if cli_cache.exists():
    for cf in cli_cache.glob('*.json'):
        try:
            cobj = json.loads(cf.read_text(encoding='utf-8', errors='ignore'))
            exp_s = cobj.get('Credentials', {}).get('Expiration')
            if exp_s:
                exp_dt = datetime.fromisoformat(exp_s.replace('Z', '+00:00'))
                if exp_dt > now_utc:
                    aws_valid = True
                    break
        except Exception:
            pass

tot = sum(cost_m.values())
pct_denom = max(tot, 0.0001)
print(f'month_usd=${tot:.2f}')
print(f'day_usd=${cost_d:.2f}')
print(f'period={cur_ym}')
print(f'aws_valid={1 if aws_valid else 0}')
for k in ('opus', 'sonnet', 'haiku'):
    print(f'{k}_pct={cost_m[k]/pct_denom*100:.1f}')
    print(f'{k}_turns={turns[k]}')
'@

$pyLines = $pyCode | python - 2>$null
$monthAmt = '$0.00'; $dayAmt = '$0.00'; $period = (Get-Date -Format 'yyyy-MM')
$opusPct = '0.0'; $sonnetPct = '0.0'; $haikuPct = '0.0'
$opusTurns = '0'; $sonnetTurns = '0'; $haikuTurns = '0'
$awsValid = $false

foreach ($l in $pyLines) {
    if ($l -match '^month_usd=(.+)$')    { $monthAmt = $Matches[1] }
    if ($l -match '^day_usd=(.+)$')      { $dayAmt = $Matches[1] }
    if ($l -match '^period=(.+)$')       { $period = $Matches[1] }
    if ($l -match '^aws_valid=1$')       { $awsValid = $true }
    if ($l -match '^opus_pct=(.+)$')     { $opusPct = $Matches[1] }
    if ($l -match '^sonnet_pct=(.+)$')   { $sonnetPct = $Matches[1] }
    if ($l -match '^haiku_pct=(.+)$')    { $haikuPct = $Matches[1] }
    if ($l -match '^opus_turns=(.+)$')   { $opusTurns = $Matches[1] }
    if ($l -match '^sonnet_turns=(.+)$') { $sonnetTurns = $Matches[1] }
    if ($l -match '^haiku_turns=(.+)$')  { $haikuTurns = $Matches[1] }
}

# Only call adi-aie if ~/.aws/cli/cache ALREADY has an active STS role credential (guarantees 0% chance of browser popup)
if ($awsValid) {
    $adi = if ($env:AI_COST_CLI) { $env:AI_COST_CLI } else { "$env:USERPROFILE\Apps\bin\adi-aie.exe" }
    if (Test-Path $adi) {
        $mOut = (& $adi user-cost --monthly 2>&1 | Out-String)
        if ($mOut -match '\$([0-9,]+\.[0-9]{2})') { $monthAmt = '$' + $Matches[1] }
        $dOut = (& $adi user-cost --daily 2>&1 | Out-String)
        if ($dOut -match '\$([0-9,]+\.[0-9]{2})') { $dayAmt = '$' + $Matches[1] }
    }
}

$updated = Get-Date -Format 'HH:mm'
$lines = @(
    "status=SYNCED",
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
