param([string]$OutFile)

$ErrorActionPreference = 'SilentlyContinue'
. "$PSScriptRoot\load_env.ps1"

$keyBat = '{104EA319-6EE2-4701-BD47-8DDBF425BBE5} 2'
$keyTs  = '{104EA319-6EE2-4701-BD47-8DDBF425BBE5} 7'
$keyCon = '{83DA6326-97A6-4088-9453-A1923F573B29} 15'

$raw = @{}
$devs = Get-CimInstance -ClassName Win32_PnPEntity -Filter "DeviceID LIKE 'BTHLE\\DEV_%' OR DeviceID LIKE 'BTHENUM\\DEV_%' OR DeviceID LIKE 'BTHENUM\\{0000111E%'" -ErrorAction SilentlyContinue
foreach ($d in $devs) {
    $fn = $d.Name -replace '\s+Hands-Free AG$','' -replace '\s+Avrcp Transport$',''
    if (-not $fn) { continue }
    $res = Invoke-CimMethod -InputObject $d -MethodName GetDeviceProperties -Arguments @{ devicePropertyKeys = @($keyBat, $keyTs, $keyCon) } -ErrorAction SilentlyContinue
    $props = $res.deviceProperties
    if (-not $props) { continue }
    $bat = $props[0].Data
    $ts  = $props[1].Data
    $con = $props[2].Data
    if ($null -eq $bat -and $null -eq $con) { continue }

    if (-not $raw.ContainsKey($fn)) {
        $raw[$fn] = @{ Name = $fn; Bat = -1; Ts = [datetime]::MinValue; Connected = $false }
    }
    $entry = $raw[$fn]
    if ($con -eq $true) { $entry.Connected = $true }
    if ($null -ne $bat -and [int]$bat -ge 0 -and [int]$bat -le 100) {
        $dt = [datetime]::MinValue
        if ($ts -is [datetime]) { $dt = $ts }
        elseif ($ts) { [datetime]::TryParse([string]$ts, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$dt) | Out-Null }
        if ($dt -ge $entry.Ts -or $entry.Bat -lt 0) {
            $entry.Bat = [int]$bat
            $entry.Ts = $dt
        }
    }
}

$headset = @{ Name = 'Headset'; Bat = 0; State = 'OFF' }
$kbd     = @{ Name = 'Keyboard'; Bat = 0; State = 'OFF' }
$mouse   = @{ Name = 'Mouse'; Bat = 0; State = 'OFF' }

foreach ($it in ($raw.Values | Where-Object { $_.Connected -and $_.Bat -ge 0 })) {
    $n = $it.Name
    if ($n -match 'Jabra|Arctis|Head|Buds|AirPods|WH-|WF-|Evolve') {
        $headset = @{ Name = $n; Bat = $it.Bat; State = 'ACTIVE' }
    } elseif ($n -match 'KEYS|Keyboard|Keychron|Kbd|108') {
        $kbd = @{ Name = $n; Bat = $it.Bat; State = 'ACTIVE' }
    } elseif ($n -match 'Mouse|MS\d+|MX Master|Anywhere|R8') {
        $mouse = @{ Name = $n; Bat = $it.Bat; State = 'ACTIVE' }
    }
}

$activeCnt = @($headset, $kbd, $mouse | Where-Object { $_.State -eq 'ACTIVE' }).Count
$lines = @(
    "active_count=$activeCnt",
    "hs_name=$($headset.Name)",
    "hs_bat=$($headset.Bat)",
    "hs_state=$($headset.State)",
    "kb_name=$($kbd.Name)",
    "kb_bat=$($kbd.Bat)",
    "kb_state=$($kbd.State)",
    "ms_name=$($mouse.Name)",
    "ms_bat=$($mouse.Bat)",
    "ms_state=$($mouse.State)"
)

if ($OutFile) {
    $dir = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllLines($OutFile, $lines, [System.Text.UTF8Encoding]::new($false))
}
