[CmdletBinding()]
param(
    [switch]$InstallDocker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $($LASTEXITCODE): $FilePath $($Arguments -join ' ')"
    }
}

function Get-PythonCommand {
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if ($launcher) {
        & $launcher.Source -3.13 --version 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return @{ FilePath = $launcher.Source; PrefixArguments = @("-3.13") }
        }
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        & $python.Source --version 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return @{ FilePath = $python.Source; PrefixArguments = @() }
        }
    }

    throw "Python 3.13 was not found. Install it, reopen PowerShell, and run this script again."
}

function Ensure-DockerDesktop {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        return
    }

    if (-not $InstallDocker) {
        Write-Warning "Docker Desktop was not found. Install it manually, or rerun .\setup.ps1 -InstallDocker."
        return
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "Winget is required to install Docker Desktop automatically. Install Docker Desktop manually instead."
    }

    Write-Host "Installing Docker Desktop through Winget..."
    Invoke-ExternalCommand -FilePath $winget.Source -Arguments @(
        "install",
        "--exact",
        "--id",
        "Docker.DockerDesktop",
        "--accept-source-agreements",
        "--accept-package-agreements"
    )
    Write-Warning "Docker Desktop was installed. Open it once to accept its terms, then reopen PowerShell before running .\run.ps1."
}

$projectRoot = $PSScriptRoot
$python = Get-PythonCommand
$venvPython = Join-Path $projectRoot ".venv\Scripts\python.exe"

Push-Location $projectRoot
try {
    if (-not (Test-Path -LiteralPath $venvPython)) {
        Write-Host "Creating Python virtual environment..."
        Invoke-ExternalCommand -FilePath $python.FilePath -Arguments @(
            $python.PrefixArguments + @("-m", "venv", ".venv")
        )
    }

    Write-Host "Installing Python dependencies..."
    Invoke-ExternalCommand -FilePath $venvPython -Arguments @("-m", "pip", "install", "-r", "requirements.txt")

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw "Node.js and npm were not found. Install the current Node.js LTS release, reopen PowerShell, and run this script again."
    }

    Write-Host "Installing frontend dependencies..."
    Push-Location "apps\web"
    try {
        Invoke-ExternalCommand -FilePath "npm" -Arguments @("ci")
    }
    finally {
        Pop-Location
    }

    if (-not (Test-Path -LiteralPath ".env")) {
        Copy-Item -LiteralPath ".env.example" -Destination ".env"
        $sessionSecret = (& $venvPython -c "import secrets; print(secrets.token_urlsafe(48))").Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to generate a session secret."
        }
        $environmentContents = Get-Content -LiteralPath ".env" -Raw
        $environmentContents = $environmentContents -replace (
            "(?m)^SESSION_SECRET=.*$",
            "SESSION_SECRET=$sessionSecret"
        )
        Set-Content -LiteralPath ".env" -Value $environmentContents -Encoding UTF8
        Write-Host "Created .env from .env.example with a unique session secret."
    }
    else {
        Write-Host "Existing .env preserved."
    }

    Ensure-DockerDesktop
    Write-Host "Setup complete. Add your OAuth credentials to .env, then run .\run.ps1."
}
finally {
    Pop-Location
}
