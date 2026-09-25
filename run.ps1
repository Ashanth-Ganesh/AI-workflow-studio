[CmdletBinding()]
param(
    [switch]$Detach,
    [switch]$NoBuild,
    [ValidateRange(10, 300)]
    [int]$DockerTimeoutSeconds = 120,
    [ValidateRange(30, 300)]
    [int]$ApplicationTimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-DockerEngine {
    & docker version --format "{{.Server.Version}}" 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

function Start-DockerDesktop {
    if (Test-DockerEngine) {
        return
    }

    Write-Host "Starting Docker Desktop..."
    & docker desktop start --detach 2>$null
    $startedWithCli = $LASTEXITCODE -eq 0

    if (-not $startedWithCli) {
        $candidates = @(
            (Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"),
            (Join-Path $env:LOCALAPPDATA "Docker\Docker Desktop.exe")
        )
        $desktopPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

        if (-not $desktopPath) {
            throw "Docker Desktop could not be started. Install Docker Desktop or start it manually."
        }

        Start-Process -FilePath $desktopPath -WindowStyle Hidden
    }

    $deadline = (Get-Date).AddSeconds($DockerTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-DockerEngine) {
            Write-Host "Docker Engine is ready."
            return
        }
        Start-Sleep -Seconds 2
    }

    throw "Docker Engine was not ready within $DockerTimeoutSeconds seconds. Check Docker Desktop for an error."
}

function Assert-LocalConfiguration {
    param([Parameter(Mandatory)][string]$ProjectRoot)

    $environmentPath = Join-Path $ProjectRoot ".env"
    if (-not (Test-Path -LiteralPath $environmentPath)) {
        throw "Missing .env. Run .\setup.ps1 first, add OAuth credentials to .env, then rerun .\run.ps1."
    }

    $environmentContents = Get-Content -LiteralPath $environmentPath -Raw
    $secretMatch = [regex]::Match($environmentContents, "(?m)^\s*SESSION_SECRET\s*=\s*(?<value>.*)$")
    $sessionSecret = if ($secretMatch.Success) { $secretMatch.Groups["value"].Value.Trim() } else { "" }
    if (-not $sessionSecret -or $sessionSecret -like "replace-with-*") {
        throw "SESSION_SECRET is missing or still uses the example value. Run .\setup.ps1 to generate one, or set a unique value in .env."
    }
}

function Assert-DockerComposeCapability {
    $composeVersion = (& docker compose version --short 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $composeVersion) {
        throw "Docker Compose v2 was not found. Update Docker Desktop, then run 'docker compose version' to confirm it is available."
    }

    $upHelp = (& docker compose up --help 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $upHelp -notmatch "(?m)^\s*--wait\b") {
        throw "Docker Compose $composeVersion does not support 'docker compose up --wait'. Update Docker Desktop, then rerun .\run.ps1."
    }

    Write-Host "Docker Compose $composeVersion is compatible."
}

function Assert-LocalPortsAvailable {
    $ports = @(
        @{ Number = 5173; Service = "web" },
        @{ Number = 8000; Service = "api" },
        @{ Number = 5432; Service = "db" }
    )
    $runningServices = @(
        & docker compose ps --status running --services 2>$null |
            Where-Object { $_ -and $_.Trim() }
    )
    if ($LASTEXITCODE -ne 0) {
        $runningServices = @()
    }

    foreach ($port in $ports) {
        if ($runningServices -contains $port.Service) {
            continue
        }

        $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $port.Number -ErrorAction SilentlyContinue)
        if ($listeners.Count -eq 0) {
            continue
        }

        $owners = foreach ($listener in $listeners) {
            try {
                $process = Get-Process -Id $listener.OwningProcess -ErrorAction Stop
                "$($process.ProcessName) (PID $($listener.OwningProcess))"
            }
            catch {
                "PID $($listener.OwningProcess)"
            }
        }
        $ownerSummary = ($owners | Sort-Object -Unique) -join ", "
        throw "Port $($port.Number) is already in use by $ownerSummary. Stop that process or container before starting the $($port.Service) service."
    }
}

function Wait-ForHttpEndpoint {
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$LogService
    )

    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
                return $null
            }
        }
        catch {
            # Services can be running before their HTTP listeners are ready.
        }
        Start-Sleep -Seconds 1
    }

    return "$Name did not respond at $Url. Check 'docker compose logs $LogService'."
}

function Show-StartupMessage {
    param([string[]]$Warnings)

    Write-Host ""
    if ($Warnings.Count -eq 0) {
        Write-Host "[OK] AI Workflow Studio started successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "[WARN] AI Workflow Studio started with $($Warnings.Count) warning(s)." -ForegroundColor Yellow
        $Warnings | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
    }
    Write-Host "   Web app:  http://localhost:5173" -ForegroundColor Green
    Write-Host "   API docs: http://localhost:8000/api/docs" -ForegroundColor Green
    Write-Host ""
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "The Docker CLI was not found. Install Docker Desktop and reopen PowerShell."
}

$projectRoot = $PSScriptRoot

$composeArguments = @(
    "compose",
    "up",
    "--wait",
    "--wait-timeout",
    $ApplicationTimeoutSeconds
)
if (-not $NoBuild) {
    $composeArguments += "--build"
}

Push-Location $projectRoot
$exitCode = 0
try {
    Assert-LocalConfiguration -ProjectRoot $projectRoot
    Assert-DockerComposeCapability
    Start-DockerDesktop
    Assert-LocalPortsAvailable

    & docker @composeArguments
    if ($LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
    }
    else {
        $warnings = [System.Collections.Generic.List[string]]::new()
        $webWarning = Wait-ForHttpEndpoint -Url "http://localhost:5173" -Name "Web app" -LogService "web"
        $apiWarning = Wait-ForHttpEndpoint -Url "http://localhost:8000/api/v1/health/ready" -Name "API" -LogService "api"
        if ($webWarning) { $warnings.Add($webWarning) }
        if ($apiWarning) { $warnings.Add($apiWarning) }

        if (-not $Detach) {
            Write-Host ""
            Write-Host "Startup logs:" -ForegroundColor DarkGray
            & docker compose logs --tail 50
        }
        Show-StartupMessage -Warnings $warnings.ToArray()

        if (-not $Detach) {
            Write-Host "Following logs. Press Ctrl+C to stop the application services." -ForegroundColor DarkGray
            try {
                & docker compose logs --follow --tail 0
            }
            finally {
                Write-Host "Stopping application services..." -ForegroundColor DarkGray
                & docker compose stop | Out-Null
            }
        }
    }
}
finally {
    Pop-Location
}

exit $exitCode
