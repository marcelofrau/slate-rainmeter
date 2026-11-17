# Shared helper to load key=value pairs from %APPDATA%\Rainmeter\SlateWork\.env or repo .env
function Import-SlateWorkEnv {
    $candidates = @(
        (Join-Path $env:APPDATA 'Rainmeter\SlateWork\.env'),
        (Join-Path $PSScriptRoot '..\..\.env'),
        (Join-Path $PSScriptRoot '..\..\..\.env')
    )
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            foreach ($line in [System.IO.File]::ReadAllLines($path)) {
                $trimmed = $line.Trim()
                if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
                if ($trimmed -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
                    $k = $Matches[1]
                    $v = $Matches[2].Trim().Trim('"').Trim("'")
                    $existing = [Environment]::GetEnvironmentVariable($k)
                    if (-not $existing) {
                        Set-Item -Path "Env:\$k" -Value $v
                    }
                }
            }
        }
    }
}
Import-SlateWorkEnv
