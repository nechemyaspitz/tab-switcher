# build.ps1 — Build, publish, and package Tab Switcher for Windows
# Usage:
#   .\build.ps1              # Build only
#   .\build.ps1 -Installer   # Build + create installer
#   .\build.ps1 -Sign        # Build + code sign

param(
    [switch]$Installer,
    [switch]$Sign,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$ProjectDir = $PSScriptRoot
$PublishDir = Join-Path $ProjectDir "dist\publish"
$InstallerDir = Join-Path $ProjectDir "installer"

Write-Host "=== Tab Switcher Windows Build ===" -ForegroundColor Cyan

# Clean
if ($Clean) {
    Write-Host "Cleaning..." -ForegroundColor Yellow
    dotnet clean "$ProjectDir\TabSwitcher\TabSwitcher.csproj" -c Release
    if (Test-Path $PublishDir) { Remove-Item -Recurse -Force $PublishDir }
}

# Build + Publish
Write-Host "Publishing..." -ForegroundColor Yellow
dotnet publish "$ProjectDir\TabSwitcher\TabSwitcher.csproj" `
    -c Release `
    -r win-x64 `
    --self-contained `
    -o $PublishDir `
    /p:PublishSingleFile=true `
    /p:IncludeNativeLibrariesForSelfExtract=true

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

$ExePath = Join-Path $PublishDir "TabSwitcher.exe"
if (-not (Test-Path $ExePath)) {
    Write-Host "ERROR: TabSwitcher.exe not found at $ExePath" -ForegroundColor Red
    exit 1
}

$FileInfo = Get-Item $ExePath
Write-Host "Build successful: $ExePath ($([math]::Round($FileInfo.Length / 1MB, 1)) MB)" -ForegroundColor Green

# Code signing
if ($Sign) {
    Write-Host "Code signing..." -ForegroundColor Yellow
    # Sign the exe with Authenticode certificate
    # Update the certificate thumbprint as needed
    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
    if ($cert) {
        Set-AuthenticodeSignature -FilePath $ExePath -Certificate $cert -TimestampServer "http://timestamp.digicert.com"
        Write-Host "Signed: $ExePath" -ForegroundColor Green
    } else {
        Write-Host "WARNING: No code signing certificate found, skipping" -ForegroundColor Yellow
    }
}

# Create installer
if ($Installer) {
    Write-Host "Creating installer..." -ForegroundColor Yellow

    $IssFile = Join-Path $InstallerDir "setup.iss"
    if (-not (Test-Path $IssFile)) {
        Write-Host "ERROR: setup.iss not found" -ForegroundColor Red
        exit 1
    }

    # Check for InnoSetup
    $Iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (-not (Test-Path $Iscc)) {
        $Iscc = Get-Command iscc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    }

    if ($Iscc -and (Test-Path $Iscc)) {
        & $Iscc $IssFile
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Installer created in dist\" -ForegroundColor Green
        } else {
            Write-Host "Installer creation failed!" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "WARNING: InnoSetup not found. Install from https://jrsoftware.org/isinfo.php" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Build complete ===" -ForegroundColor Cyan
