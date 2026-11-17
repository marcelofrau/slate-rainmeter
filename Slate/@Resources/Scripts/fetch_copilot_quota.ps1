param([string]$OutFile)

$ErrorActionPreference = 'SilentlyContinue'
$quotaRoot = Get-ChildItem "$env:USERPROFILE\.cache\opencode\npm\@slkiser\opencode-quota@*" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$distDir = $null
if ($quotaRoot) {
    $sub = Get-ChildItem $quotaRoot.FullName -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sub) {
        $cand = Join-Path $sub.FullName 'node_modules\@slkiser\opencode-quota\dist'
        if (Test-Path $cand) { $distDir = $cand }
    }
}

$status = 'OFFLINE'
$leftPct = '0.0'
$used = '0'
$total = '0'
$rem = '0'
$plan = 'BUSINESS'
$resetDays = '--'
$updated = Get-Date -Format 'HH:mm'

if ($distDir) {
    $distUrl = 'file:///' + ($distDir -replace '\\','/')
    $js = @"
import { createSqliteCredentialSource } from "$distUrl/lib/opencode-auth-sqlite.js";
import { bindCredentialSource } from "$distUrl/lib/opencode-auth.js";
import { queryCopilotQuota, readCopilotLogins } from "$distUrl/lib/copilot.js";
const unbind = bindCredentialSource(createSqliteCredentialSource());
try {
  const logins = await readCopilotLogins();
  for (const row of logins.oauth) {
    const res = await queryCopilotQuota({ login: row });
    if (res && res.success) {
      console.log(JSON.stringify(res));
      break;
    }
  }
} finally {
  unbind();
}
"@
    $jsonLine = ($js | node --input-type=module - 2>$null | Select-Object -Last 1)
    if ($jsonLine) {
        try {
            $obj = $jsonLine | ConvertFrom-Json
            if ($obj.success) {
                $status = 'SYNCED'
                $u = [double]($obj.used ?? 0)
                $t = [double]($obj.total ?? 0)
                $p = [double]($obj.percentRemaining ?? 0)
                $r = [Math]::Max(0, $t - $u)
                $leftPct = $p.ToString('0.0', [cultureinfo]::InvariantCulture)
                $used = ([int][Math]::Round($u)).ToString([cultureinfo]::InvariantCulture)
                $total = ([int][Math]::Round($t)).ToString([cultureinfo]::InvariantCulture)
                $rem = ([int][Math]::Round($r)).ToString([cultureinfo]::InvariantCulture)
                if ($obj.plan) { $plan = ([string]$obj.plan).ToUpperInvariant() }
                if ($obj.resetTimeIso) {
                    $dt = [DateTimeOffset]::Parse([string]$obj.resetTimeIso, [cultureinfo]::InvariantCulture)
                    $days = ($dt - [DateTimeOffset]::UtcNow).TotalDays
                    if ($days -ge 0) {
                        $resetDays = $days.ToString('0.0', [cultureinfo]::InvariantCulture) + 'd'
                    }
                }
            }
        } catch {}
    }
}

$lines = @(
    "status=$status",
    "left_pct=$leftPct",
    "used=$used",
    "total=$total",
    "rem=$rem",
    "plan=$plan",
    "reset_days=$resetDays",
    "updated=$updated"
)
if ($OutFile) {
    $dir = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllLines($OutFile, $lines, [System.Text.UTF8Encoding]::new($false))
}
