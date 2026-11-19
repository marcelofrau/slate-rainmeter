# Slate deploy - copies the suite to Rainmeter's SkinPath and activates the skins
# Usage: pwsh -NoProfile -File .\deploy.ps1 [-NoActivate] [-ProfileName Home|Work] [-WorkMonitorIndex N] [-ListMonitors]
param(
    [switch]$NoActivate,
    [ValidateSet('Home', 'Work')][string]$ProfileName = 'Home',
    [int]$WorkMonitorIndex = -1,
    [switch]$ListMonitors
)

function Get-SlateMonitors {
    if (-not ('SlateMonitorHelper' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class SlateMonitorInfo {
    public string DeviceName;
    public bool Primary;
    public int DpiX;
    public double Scale;
    public int X;
    public int Y;
    public int Width;
    public int Height;
    public int WorkX;
    public int WorkY;
    public int WorkWidth;
    public int WorkHeight;
    public int WorkRight;
}

public class SlateMonitorHelper {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct MONITORINFOEX {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string szDevice;
    }

    public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT lprcMonitor, IntPtr dwData);

    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr value);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfnEnum, IntPtr dwData);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFOEX lpmi);

    [DllImport("Shcore.dll")]
    public static extern int GetDpiForMonitor(IntPtr hmonitor, int dpiType, out uint dpiX, out uint dpiY);

    public static List<SlateMonitorInfo> GetMonitors() {
        try { SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch {}
        var list = new List<SlateMonitorInfo>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, delegate(IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr d) {
            MONITORINFOEX mi = new MONITORINFOEX();
            mi.cbSize = Marshal.SizeOf(typeof(MONITORINFOEX));
            uint dx = 96, dy = 96;
            try { GetDpiForMonitor(hMon, 0, out dx, out dy); } catch {}
            if (GetMonitorInfo(hMon, ref mi)) {
                var info = new SlateMonitorInfo();
                info.DeviceName = mi.szDevice;
                info.Primary = (mi.dwFlags & 1) != 0;
                info.DpiX = (int)dx;
                info.Scale = (double)dx / 96.0;
                info.X = mi.rcMonitor.Left;
                info.Y = mi.rcMonitor.Top;
                info.Width = mi.rcMonitor.Right - mi.rcMonitor.Left;
                info.Height = mi.rcMonitor.Bottom - mi.rcMonitor.Top;
                info.WorkX = mi.rcWork.Left;
                info.WorkY = mi.rcWork.Top;
                info.WorkWidth = mi.rcWork.Right - mi.rcWork.Left;
                info.WorkHeight = mi.rcWork.Bottom - mi.rcWork.Top;
                info.WorkRight = mi.rcWork.Right;
                list.Add(info);
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
'@
    }
    return [SlateMonitorHelper]::GetMonitors()
}

    if ($ListMonitors) {
        $screens = Get-SlateMonitors
        for ($i = 0; $i -lt $screens.Count; $i++) {
            $s = $screens[$i]
            $pct = [int][Math]::Round($s.Scale * 100)
            $lx = [int][Math]::Round($s.X / $s.Scale)
            $ly = [int][Math]::Round($s.Y / $s.Scale)
            $lw = [int][Math]::Round($s.Width / $s.Scale)
            $lh = [int][Math]::Round($s.Height / $s.Scale)
            Write-Host "[$i] $($s.DeviceName) Physical=$($s.Width)x$($s.Height) at ($($s.X),$($s.Y)) | Logical=${lw}x${lh} at (${lx},${ly}) Scale=${pct}% Primary=$($s.Primary)"
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
    $screens = Get-SlateMonitors
    if ($WorkMonitorIndex -lt 0) {
        $secondary = @()
        for ($i = 0; $i -lt $screens.Count; $i++) {
            if (-not $screens[$i].Primary) { $secondary += $i }
        }
        if ($secondary.Count -ne 1) {
            throw 'Work profile needs one secondary monitor. Run .\deploy.ps1 -ListMonitors and pass -WorkMonitorIndex N.'
        }
        $WorkMonitorIndex = $secondary[0]
    }
    if ($WorkMonitorIndex -ge $screens.Count) {
        throw "Monitor index $WorkMonitorIndex does not exist. Run .\deploy.ps1 -ListMonitors."
    }
    $workScreen = $screens[$WorkMonitorIndex]
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
        $sc = $workScreen.Scale
        $logRight  = [int][Math]::Round($workScreen.WorkRight / $sc)
        $logY      = [int][Math]::Round($workScreen.WorkY / $sc)
        $logHeight = [int][Math]::Round($workScreen.WorkHeight / $sc)
        $workStackH = 792
        $workCol3X = $logRight - 256 - 96
        $workCol2X = $workCol3X - 8 - 256
        $workCol1X = $workCol2X - 8 - 256
        $workY = $logY + [int][Math]::Floor(($logHeight - $workStackH) / 2)
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

    # Ensure cards are locked by default (Draggable=0) and invoke dynamic relayout
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$dst\@Resources\Scripts\relayout.ps1" -Action Realign -Force
    Write-Host "Slate $ProfileName profile activated and dynamically aligned (cards locked by default)"
}
