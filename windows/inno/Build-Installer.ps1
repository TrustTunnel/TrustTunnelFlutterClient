[CmdletBinding()]
param(
    [ValidateSet("Debug", "Profile", "Release")]
    [string]$Configuration = "Release",

    [ValidatePattern("^\d+\.\d+\.\d+([\-+][0-9A-Za-z.-]+)?$")]
    [string]$AppVersion = "1.2.0",

    [ValidateRange(0, 65535)]
    [int]$BuildNumber = 0,

    [ValidateSet("x64", "arm64")]
    [string]$Architecture,

    [switch]$SkipFlutterBuild,

    [switch]$ForceDownload
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($env:OS -ne "Windows_NT") {
    throw "The Windows installer can only be built on Windows."
}

$scriptDir = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$versionMatch = [regex]::Match($AppVersion, "^(\d+)\.(\d+)\.(\d+)")
$numericVersion = "{0}.{1}.{2}.{3}" -f `
    $versionMatch.Groups[1].Value, `
    $versionMatch.Groups[2].Value, `
    $versionMatch.Groups[3].Value, `
    $BuildNumber

$hostArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
if (-not $Architecture) {
    $Architecture = switch ($hostArchitecture) {
        'X64' { 'x64' }
        'Arm64' { 'arm64' }
        default { throw "Unsupported Windows architecture: $hostArchitecture" }
    }
}
switch ($Architecture) {
    "x64" {
        $vcRedistName = "vc_redist.x64.exe"
        $vcRedistUrl = "https://aka.ms/vc14/vc_redist.x64.exe"
    }
    "arm64" {
        $vcRedistName = "vc_redist.arm64.exe"
        $vcRedistUrl = "https://aka.ms/vc14/vc_redist.arm64.exe"
    }
}

if (-not $SkipFlutterBuild) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw "Flutter was not found in PATH."
    }

    if ([string]::IsNullOrWhiteSpace($env:GPR_KEY)) {
        throw "GPR_KEY is not set. A GitHub token with read:packages is required."
    }

    Push-Location $repoRoot
    try {
        $buildMode = $Configuration.ToLowerInvariant()
        & flutter clean
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter clean failed with exit code $LASTEXITCODE."
        }

        & flutter build windows `
            "--$buildMode" `
            "--build-name=$AppVersion" `
            "--build-number=$BuildNumber"
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter Windows build failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

$buildDir = Join-Path $repoRoot "build\windows\$Architecture\runner\$Configuration"
$requiredBundleItems = @(
    "TrustTunnel.exe",
    "cleanup_user_data_helper.exe",
    "app_links_plugin.dll",
    "flutter_windows.dll",
    "screen_retriever_windows_plugin.dll",
    "sqlite3.dll",
    "sqlite3_flutter_libs_plugin.dll",
    "url_launcher_windows_plugin.dll",
    "vpn_plugin_plugin.dll",
    "window_manager_plugin.dll",
    "trusttunnel.dll",
    "trusttunnel_service.exe",
    "trusttunnel_service_installer.exe",
    "wintun.dll",
    "WINTUN_LICENSE.txt",
    "data\icudtl.dat",
    "data\flutter_assets"
)
if ($Configuration -ne "Debug") {
    $requiredBundleItems += "data\app.so"
}

foreach ($item in $requiredBundleItems) {
    $itemPath = Join-Path $buildDir $item
    if (-not (Test-Path $itemPath)) {
        throw "Required release bundle item is missing: $itemPath"
    }
}
$cacheDir = Join-Path $scriptDir ".cache"
New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
$vcRedistPath = Join-Path $cacheDir $vcRedistName

if ($ForceDownload -or -not (Test-Path $vcRedistPath)) {
    Invoke-WebRequest -Uri $vcRedistUrl -OutFile $vcRedistPath
}

$vcRedistSignature = Get-AuthenticodeSignature $vcRedistPath
if (
    $vcRedistSignature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
    $vcRedistSignature.SignerCertificate.Subject -notmatch "Microsoft"
) {
    throw "The downloaded Visual C++ Redistributable has an invalid Microsoft signature."
}

$isccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
$isccCandidates = @()
if ($isccCommand) {
    $isccCandidates += $isccCommand.Source
}
$programFilesX86 = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::ProgramFilesX86
)
$localAppData = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::LocalApplicationData
)
$isccCandidates += @(
    (Join-Path $localAppData "Programs\Inno Setup 6\ISCC.exe"),
    (Join-Path $programFilesX86 "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
)
$isccPath = $isccCandidates |
    Where-Object { $_ -and (Test-Path $_) } |
    Select-Object -First 1

if (-not $isccPath) {
    throw "Inno Setup 6 was not found. Install it with: winget install JRSoftware.InnoSetup"
}

$isccVersion = [version](Get-Item $isccPath).VersionInfo.FileVersion
# If the version is 0.0.0.0 (bug???), try to find the version from the registry
if ($isccVersion -eq [version]"0.0.0.0") {
    $innoRegistryKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1"
    )
    $installedVersion = $innoRegistryKeys |
        ForEach-Object {
            Get-ItemProperty $_ -ErrorAction SilentlyContinue
        } |
        Where-Object {
            $_.InstallLocation -and
            $isccPath.StartsWith($_.InstallLocation, [StringComparison]::OrdinalIgnoreCase)
        } |
        Select-Object -ExpandProperty DisplayVersion -First 1

    if ($installedVersion) {
        $isccVersion = [version]$installedVersion
    }
}
if ($isccVersion -lt [version]"6.6") {
    throw "Inno Setup 6.6 or newer is required. Found: $isccVersion"
}

$outputDir = Join-Path $repoRoot "build\windows\installer"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$issPath = Join-Path $scriptDir "TrustTunnel.iss"
$isccArguments = @(
    "/DAppVersion=$AppVersion",
    "/DNumericVersion=$numericVersion",
    "/DAppArchitecture=$Architecture",
    "/DBuildDir=$buildDir",
    "/DOutputDir=$outputDir",
    "/DVcRedistPath=$vcRedistPath",
    $issPath
)

& $isccPath @isccArguments
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE."
}

$installerPath = Join-Path $outputDir "TrustTunnelSetup-$Architecture.exe"
if (-not (Test-Path $installerPath)) {
    throw "The installer was not created at the expected path: $installerPath"
}

Write-Host "Installer created: $installerPath" -ForegroundColor Green
