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
Start-DockerDesktop

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
