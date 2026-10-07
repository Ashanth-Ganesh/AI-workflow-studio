[CmdletBinding()]
param(
    [switch]$InstallPrerequisites,
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

function Refresh-CommandPath {
    # Installers update the registry PATH, but not the PowerShell process already running.
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machinePath, $userPath, $env:Path) | Where-Object { $_ }) -join ";"
}

function Get-WingetCommand {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        return $winget.Source
    }

    $windowsAppsWinget = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path -LiteralPath $windowsAppsWinget) {
        return $windowsAppsWinget
    }
    return $null
}

function Ensure-Winget {
    $winget = Get-WingetCommand
    if ($winget) {
        return $winget
    }

    if (-not ($InstallPrerequisites -or $InstallDocker)) {
        throw "WinGet is required for automatic installation. Rerun with -InstallPrerequisites or install Windows App Installer."
    }

    Write-Host "WinGet is missing. Registering or installing Windows App Installer..."
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "App Installer was not already registered; trying Microsoft's WinGet repair module..."
    }
    Refresh-CommandPath
    $winget = Get-WingetCommand
    if ($winget) {
        return $winget
    }

    try {
        Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Scope CurrentUser -Force -Repository PSGallery -ErrorAction Stop | Out-Null
        Repair-WinGetPackageManager -Force -Latest -ErrorAction Stop | Out-Null
    }
    catch {
        throw "Could not bootstrap WinGet automatically. Install Windows App Installer from Microsoft, then rerun setup. Details: $($_.Exception.Message)"
    }

    Refresh-CommandPath
    $winget = Get-WingetCommand
    if (-not $winget) {
        throw "WinGet was installed but is not available yet. Reopen PowerShell and rerun .\setup.ps1 -InstallPrerequisites."
    }
    return $winget
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,
        [Parameter(Mandatory)]
        [string]$DisplayName
    )

    $winget = Ensure-Winget

    Write-Host "Installing $DisplayName through Winget..."
    Invoke-ExternalCommand -FilePath $winget -Arguments @(
        "install",
        "--exact",
        "--id", $PackageId,
        "--source", "winget",
        "--accept-source-agreements",
        "--accept-package-agreements"
    )
    Refresh-CommandPath
}

function Get-PythonCommand {
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if ($launcher) {
        try {
            $version = & $launcher.Source -3.13 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
            if ($LASTEXITCODE -eq 0 -and $version -eq "3.13") {
                return @{ FilePath = $launcher.Source; PrefixArguments = @("-3.13") }
            }
        }
        catch {
            # Another Python version may be installed without Python 3.13.
        }
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        try {
            $version = & $python.Source -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
            if ($LASTEXITCODE -eq 0 -and $version -eq "3.13") {
                return @{ FilePath = $python.Source; PrefixArguments = @() }
            }
        }
        catch {
            # Ignore a broken executable or a Windows Store alias.
        }
    }

    $userPython = Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"
    if (Test-Path -LiteralPath $userPython) {
        try {
            $version = & $userPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
            if ($LASTEXITCODE -eq 0 -and $version -eq "3.13") {
                return @{ FilePath = $userPython; PrefixArguments = @() }
            }
        }
        catch {
            # Continue to the missing-interpreter message below.
        }
    }

    return $null
}

function Ensure-Python {
    $python = Get-PythonCommand
    if ($python) {
        return $python
    }

    if (-not $InstallPrerequisites) {
        throw "Python 3.13 was not found. Install it manually or rerun .\setup.ps1 -InstallPrerequisites."
    }

    Install-WingetPackage -PackageId "Python.Python.3.13" -DisplayName "Python 3.13"
    $python = Get-PythonCommand
    if (-not $python) {
        throw "Python 3.13 was installed but is not available in this PowerShell session. Reopen PowerShell and rerun .\setup.ps1."
    }
    return $python
}

function Test-NodeAndNpmVersion {
    $node = Get-Command node -ErrorAction SilentlyContinue
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $node -or -not $npm) {
        return $false
    }

    try {
        $versionText = (& $node.Source --version 2>$null).Trim().TrimStart("v")
        & $npm.Source --version 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }
    catch {
        return $false
    }
    $nodeVersion = [version]::new(0, 0)
    if (-not [version]::TryParse($versionText, [ref]$nodeVersion)) {
        return $false
    }

    return ($nodeVersion -ge [version]"20.19.0" -and $nodeVersion.Major -eq 20) -or ($nodeVersion -ge [version]"22.12.0")
}

function Ensure-NodeAndNpm {
    if (Test-NodeAndNpmVersion) {
        return (Get-Command npm.cmd).Source
    }

    if (-not $InstallPrerequisites) {
        throw "Compatible Node.js and npm were not found. Install Node.js 20.19+ or 22.12+, or rerun .\setup.ps1 -InstallPrerequisites."
    }

    Install-WingetPackage -PackageId "OpenJS.NodeJS.LTS" -DisplayName "Node.js LTS"
    if (-not (Test-NodeAndNpmVersion)) {
        throw "Node.js LTS was installed but is not available in this PowerShell session. Reopen PowerShell and rerun .\setup.ps1."
    }
    return (Get-Command npm.cmd).Source
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

    if (-not ($InstallPrerequisites -or $InstallDocker)) {
        Write-Warning "Docker Desktop was not found. Install it manually, or rerun .\setup.ps1 -InstallPrerequisites."
        return
    }

    Install-WingetPackage -PackageId "Docker.DockerDesktop" -DisplayName "Docker Desktop"
    Write-Warning "Docker Desktop was installed. Open it once to accept its terms, then reopen PowerShell before running .\run.ps1."
}

function Ensure-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        return
    }

    if ($InstallPrerequisites) {
        Install-WingetPackage -PackageId "Git.Git" -DisplayName "Git"
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Warning "Git was installed but may need a new PowerShell session before it is available."
        }
    }
    else {
        Write-Warning "Git was not found. It is optional for running a downloaded project, but needed to clone and contribute to the repository."
    }
}

$projectRoot = $PSScriptRoot
$venvPython = Join-Path $projectRoot ".venv\Scripts\python.exe"

Push-Location $projectRoot
try {
    $python = Ensure-Python
    $npmCommand = Ensure-NodeAndNpm
    Ensure-DockerDesktop
    Ensure-Git

    if (-not (Test-Path -LiteralPath $venvPython)) {
        Write-Host "Creating Python virtual environment..."
        Invoke-ExternalCommand -FilePath $python.FilePath -Arguments @(
            $python.PrefixArguments + @("-m", "venv", ".venv")
        )
    }
    else {
        $venvVersion = (& $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
        if ($LASTEXITCODE -ne 0 -or $venvVersion -ne "3.13") {
            throw "The existing .venv does not use Python 3.13. Move it aside, then rerun .\setup.ps1 to create a compatible environment."
        }
    }

    Write-Host "Installing Python dependencies..."
    Invoke-ExternalCommand -FilePath $venvPython -Arguments @("-m", "pip", "install", "-r", "requirements.txt")

    Write-Host "Installing frontend dependencies..."
    Push-Location "apps\web"
    try {
        Invoke-ExternalCommand -FilePath $npmCommand -Arguments @("ci")
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
    $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCommand) {
        Write-Warning "Docker CLI is still unavailable. Complete Docker Desktop's first run or reopen PowerShell before using .\run.ps1."
    }
    else {
        & $dockerCommand.Source compose version --short 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Docker Compose is unavailable. Complete Docker Desktop's first run or update Docker Desktop before using .\run.ps1."
        }
    }
    Write-Host "Setup complete. Add your OAuth credentials to .env, then run .\run.ps1."
}
finally {
    Pop-Location
}
