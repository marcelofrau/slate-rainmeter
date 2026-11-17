# Slate deploy - copies the suite to Rainmeter's SkinPath and activates the skins
# Usage: pwsh -NoProfile -File .\deploy.ps1 [-NoActivate] [-ProfileName Home|Work] [-WorkMonitorIndex N] [-ListMonitors]
param(
    [switch]$NoActivate,
    [ValidateSet('Home', 'Work')][string]$ProfileName = 'Home',
    [int]$WorkMonitorIndex = -1,
    [switch]$ListMonitors
)

if ($ListMonitors) {
    Add-Type -AssemblyName System.Windows.Forms
    $screens = [System.Windows.Forms.Screen]::AllScreens
    for ($i = 0; $i -lt $screens.Length; $i++) {
        $screen = $screens[$i]
        $bounds = $screen.Bounds
        Write-Host "[$i] $($screen.DeviceName) $($bounds.Width)x$($bounds.Height) at ($($bounds.X),$($bounds.Y)) Primary=$($screen.Primary)"
    }
    exit 0
}

$src = "$PSScriptRoot\Slate"
$rm  = "C:\Program Files\Rainmeter\Rainmeter.exe"

# Auto-detect SkinPath from Rainmeter.ini (falls back to standard Documents\Rainmeter\Skins)
$rmIni = "$env:APPDATA\Rainmeter\Rainmeter.ini"
$skinBase = "$env:USERPROFILE\Documents\Rainmeter\Skins"
if (Test-Path $rmIni) {
    $spLine = (Get-Content $rmIni | Where-Object { $_ -match '^SkinPath=' } | Select-Object -First 1)
    if ($spLine) {
        $detected = ($spLine -replace '^SkinPath=','').TrimEnd('\')
        if (Test-Path $detected) { $skinBase = $detected }
    }
}
$dst = "$skinBase\Slate"

$workScreen = $null
if ($ProfileName -eq 'Work' -and -not $NoActivate) {
    Add-Type -AssemblyName System.Windows.Forms
    $screens = [System.Windows.Forms.Screen]::AllScreens
    if ($WorkMonitorIndex -lt 0) {
        $secondary = @()
        for ($i = 0; $i -lt $screens.Length; $i++) {
            if (-not $screens[$i].Primary) { $secondary += $i }
        }
        if ($secondary.Count -ne 1) {
            throw 'Work profile needs one secondary monitor. Run .\deploy.ps1 -ListMonitors and pass -WorkMonitorIndex N.'
        }
        $WorkMonitorIndex = $secondary[0]
    }
    if ($WorkMonitorIndex -ge $screens.Length) {
        throw "Monitor index $WorkMonitorIndex does not exist. Run .\deploy.ps1 -ListMonitors."
    }
    $workScreen = $screens[$WorkMonitorIndex].WorkingArea
}

robocopy $src $dst /MIR /NJH /NJS /NDL | Out-Null
if ($LASTEXITCODE -ge 8) { Write-Host "robocopy failed ($LASTEXITCODE)"; exit 1 }

# Convert .ini/.inc to UTF-16 LE (Unicode), which Rainmeter 4.5+ requires for Unicode symbols
Get-ChildItem $dst -Recurse -Include *.ini,*.inc | ForEach-Object {
    $text = [System.IO.File]::ReadAllText($_.FullName)
    [System.IO.File]::WriteAllText($_.FullName, $text, [System.Text.Encoding]::Unicode)
}

Write-Host "Deploy OK -> $dst"

if ($ProfileName -eq 'Work' -and -not $NoActivate) {
    $workDataDir = Join-Path $env:APPDATA 'Rainmeter\SlateWork'
    New-Item -ItemType Directory -Path $workDataDir -Force | Out-Null
    $localEnv = Join-Path $PSScriptRoot '.env'
    if (Test-Path $localEnv) {
        Copy-Item $localEnv (Join-Path $workDataDir '.env') -Force
    }
    $notesPath = Join-Path $workDataDir 'work-notes.txt'
    if (-not (Test-Path $notesPath)) {
        [System.IO.File]::WriteAllText($notesPath, '')
    }
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$dst\@Resources\Scripts\fetch_ai_cost.ps1" -OutFile (Join-Path $workDataDir 'ai-cost.txt')
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$dst\@Resources\Scripts\fetch_copilot_quota.ps1" -OutFile (Join-Path $workDataDir 'copilot-quota.txt')
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$dst\@Resources\Scripts\fetch_work_comms.ps1" -OutFile (Join-Path $workDataDir 'work-comms.txt')
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$dst\@Resources\Scripts\fetch_bluetooth.ps1" -OutFile (Join-Path $workDataDir 'bluetooth.txt')
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$dst\@Resources\Scripts\fetch_jira.ps1" -OutFile (Join-Path $workDataDir 'jira.txt')
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$dst\@Resources\Scripts\fetch_confluence.ps1" -OutFile (Join-Path $workDataDir 'confluence.txt')
}

& $rm !RefreshApp
Start-Sleep -Milliseconds 2000

if (-not $NoActivate) {
    # Home coordinates remain the existing default; Work adds its cards to the laptop panel.
    $configs = @(
        @{c='Slate\DesktopClock';   i='DesktopClock.ini';   x=220;  y=760},
        @{c='Slate\Visualizer';     i='Visualizer.ini';     x=220;  y=1010},
        @{c='Slate\Clock';          i='Clock.ini';          x=1944; y=288},
        @{c='Slate\WorldClock';     i='WorldClock.ini';     x=1944; y=424},
        @{c='Slate\Weather';        i='Weather.ini';        x=1944; y=496},
        @{c='Slate\WeatherDetails'; i='WeatherDetails.ini'; x=1944; y=632},
        @{c='Slate\SunMoon';        i='SunMoon.ini';        x=1944; y=704},
        @{c='Slate\Calendar';       i='Calendar.ini';       x=1944; y=776},
        @{c='Slate\CPU';            i='CPU.ini';            x=2208; y=288},
        @{c='Slate\RAM';            i='RAM.ini';            x=2208; y=424},
        @{c='Slate\GPU';            i='GPU.ini';            x=2208; y=496},
        @{c='Slate\Disk';           i='Disk.ini';           x=2208; y=632},
        @{c='Slate\Network';        i='Network.ini';        x=2208; y=768},
        @{c='Slate\Media';          i='Media.ini';          x=2208; y=904},
        @{c='Slate\Volume';         i='Volume.ini';         x=2208; y=976}
    )

    if ($ProfileName -eq 'Work') {
        $workStackH = 128 + 8 + 128 + 8 + 128 + 8 + 384
        $workCol3X = $workScreen.Right - 256 - 96
        $workCol2X = $workCol3X - 8 - 256
        $workCol1X = $workCol2X - 8 - 256
        $workY = $workScreen.Y + [int][Math]::Floor(($workScreen.Height - $workStackH) / 2)
        & $rm '!DeactivateConfig' 'Slate\Work'
        $configs += @(
            @{c='Slate\Work\Comms';        i='Comms.ini';        x=$workCol1X; y=$workY},
            @{c='Slate\Work\Bluetooth';    i='Bluetooth.ini';    x=$workCol1X; y=($workY + 328)},
            @{c='Slate\Work\Jira';         i='Jira.ini';         x=$workCol1X; y=($workY + 400)},
            @{c='Slate\Work\Confluence';   i='Confluence.ini';   x=$workCol1X; y=($workY + 600)},
            @{c='Slate\Work\ClaudeCost';   i='ClaudeCost.ini';   x=$workCol2X; y=$workY},
            @{c='Slate\Work\CopilotQuota'; i='CopilotQuota.ini'; x=$workCol2X; y=($workY + 136)},
            @{c='Slate\Work\AIModels';     i='AIModels.ini';     x=$workCol2X; y=($workY + 272)},
            @{c='Slate\Work\Battery';      i='Battery.ini';      x=$workCol3X; y=$workY},
            @{c='Slate\Work\Focus';        i='Focus.ini';        x=$workCol3X; y=($workY + 136)},
            @{c='Slate\Work\Stopwatch';    i='Stopwatch.ini';    x=$workCol3X; y=($workY + 272)},
            @{c='Slate\Work\Notes';        i='Notes.ini';        x=$workCol3X; y=($workY + 408)}
        )
    }

    foreach ($cfg in $configs) {
        & $rm "!ActivateConfig" $cfg.c $cfg.i
        Start-Sleep -Milliseconds 1200
        & $rm "!Move" $cfg.x $cfg.y $cfg.c
        Start-Sleep -Milliseconds 400
    }
    Write-Host "Slate $ProfileName profile activated and positioned"

    # Lock card positions (Draggable=0) in Rainmeter.ini so accidental clicks never move them
    Start-Sleep -Milliseconds 1500
    & $rm !Quit
    Start-Sleep -Milliseconds 2500
    $lines = [System.IO.File]::ReadAllLines($rmIni)
    $out = New-Object System.Collections.Generic.List[string]
    $inSlateCard = $false
    $wroteDrag = $false
    foreach ($l in $lines) {
        if ($l -match '^\[(.+)\]') {
            if ($inSlateCard -and -not $wroteDrag) {
                $out.Add('Draggable=0')
            }
            $sec = $Matches[1]
            $inSlateCard = ($sec -match '^Slate\\(Work\\)?(Clock|WorldClock|Weather|WeatherDetails|SunMoon|Calendar|Media|Volume|CPU|RAM|GPU|Disk|Network|Battery|Focus|Stopwatch|Notes|AIModels|ClaudeCost|CopilotQuota|Comms|Bluetooth|Jira|Confluence)$')
            $wroteDrag = $false
            $out.Add($l)
        } elseif ($inSlateCard -and $l -match '^Draggable=') {
            $out.Add('Draggable=0')
            $wroteDrag = $true
        } else {
            $out.Add($l)
        }
    }
    if ($inSlateCard -and -not $wroteDrag) { $out.Add('Draggable=0') }
    [System.IO.File]::WriteAllLines($rmIni, $out, [System.Text.Encoding]::Unicode)

    if ($ProfileName -eq 'Home') {
        $layoutIni = "$env:APPDATA\Rainmeter\Layouts\keita_quanto\Rainmeter.ini"
        if (Test-Path $layoutIni) {
            Copy-Item $rmIni $layoutIni -Force
        }
    } else {
        $layoutDir = "$env:APPDATA\Rainmeter\Layouts\Slate_Work"
        New-Item -ItemType Directory -Path $layoutDir -Force | Out-Null
        Copy-Item $rmIni (Join-Path $layoutDir 'Rainmeter.ini') -Force
    }
    Start-Process $rm
    Write-Host "Cards locked (Draggable=0); layout $ProfileName saved separately"
}
