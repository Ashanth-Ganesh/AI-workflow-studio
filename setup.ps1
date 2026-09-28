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
        & $launcher.Source -3.13 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return @{ FilePath = $launcher.Source; PrefixArguments = @("-3.13") }
        }
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        $version = (& $python.Source -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null).Trim()
        if ($LASTEXITCODE -eq 0 -and $version -eq "3.13") {
            return @{ FilePath = $python.Source; PrefixArguments = @() }
        }
    }

    throw "Python 3.13 was not found. Install Python 3.13, reopen PowerShell, and run this script again."
}

function Assert-NodeAndNpmVersion {
    $node = Get-Command node -ErrorAction SilentlyContinue
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $node -or -not $npm) {
        throw "Node.js and npm were not found. Install Node.js 20.19+ or 22.12+, reopen PowerShell, and run this script again."
    }

    $versionText = (& $node.Source --version 2>$null).Trim().TrimStart("v")
    $nodeVersion = [version]::new(0, 0)
    if (-not [version]::TryParse($versionText, [ref]$nodeVersion)) {
        throw "Unable to determine the Node.js version. Install Node.js 20.19+ or 22.12+."
    }

    $isSupported = ($nodeVersion -ge [version]"20.19.0" -and $nodeVersion.Major -eq 20) -or ($nodeVersion -ge [version]"22.12.0")
    if (-not $isSupported) {
        throw "Node.js $nodeVersion is not supported. Install Node.js 20.19+ or 22.12+."
    }
}

function Get-EnvironmentValue {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string]$Name
    )

    $contents = Get-Content -LiteralPath $FilePath -Raw
    $pattern = "(?m)^\s*{0}\s*=\s*(?<value>.*)$" -f [regex]::Escape($Name)
    $match = [regex]::Match($contents, $pattern)
    if ($match.Success) {
        return $match.Groups["value"].Value.Trim()
    }
    return ""
}

function Show-OAuthProviderStatus {
    param([Parameter(Mandatory)][string]$EnvironmentPath)

    $providers = @(
        @{ Name = "GitHub"; ClientId = "GITHUB_CLIENT_ID"; ClientSecret = "GITHUB_CLIENT_SECRET" },
        @{ Name = "Google"; ClientId = "GOOGLE_CLIENT_ID"; ClientSecret = "GOOGLE_CLIENT_SECRET" },
        @{ Name = "Microsoft"; ClientId = "MICROSOFT_CLIENT_ID"; ClientSecret = "MICROSOFT_CLIENT_SECRET" }
    )
    $configuredCount = 0

    Write-Host ""
    Write-Host "OAuth provider readiness:" -ForegroundColor DarkGray
    foreach ($provider in $providers) {
        $clientId = Get-EnvironmentValue -FilePath $EnvironmentPath -Name $provider.ClientId
        $clientSecret = Get-EnvironmentValue -FilePath $EnvironmentPath -Name $provider.ClientSecret
        if ($clientId -and $clientSecret) {
            $configuredCount++
            Write-Host "  [OK] $($provider.Name): configured" -ForegroundColor Green
        }
        elseif ($clientId -or $clientSecret) {
            Write-Host "  [WARN] $($provider.Name): incomplete credentials" -ForegroundColor Yellow
        }
        else {
            Write-Host "  [--] $($provider.Name): not configured" -ForegroundColor DarkGray
        }
    }

    if ($configuredCount -eq 0) {
        Write-Warning "No OAuth providers are configured. Add credentials to .env before users can sign in."
    }
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

    Assert-NodeAndNpmVersion

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

    Show-OAuthProviderStatus -EnvironmentPath (Join-Path $projectRoot ".env")
    Ensure-DockerDesktop
    Write-Host "Setup complete. Add your OAuth credentials to .env, then run .\run.ps1."
}
finally {
    Pop-Location
}
