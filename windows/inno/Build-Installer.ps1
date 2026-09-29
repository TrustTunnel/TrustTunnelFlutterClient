# Builds Flutter for Windows, then packages the app and VC++ runtime into an
# EXE installer with Inno Setup 6.6+.
# From the repository root on Windows (Flutter and GPR_KEY required):
#   .\windows\inno\Build-Installer.ps1 -Architecture x64
# For Windows 11 ARM64 with an x64 UI and native ARM64 VPN service:
#   .\windows\inno\Build-Installer.ps1 -Architecture arm64 -MixedArm64 -Arm64NativeArchive <path-to-aarch64-zip>

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

    [switch]$MixedArm64,

    [string]$Arm64NativeArchive,

    [string]$BundlePath,

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
$flutterArchitecture = if ($MixedArm64) { 'x64' } else { $Architecture }
if ($MixedArm64 -and $Architecture -ne 'arm64') {
    throw 'MixedArm64 requires -Architecture arm64.'
}
if ($Arm64NativeArchive -and -not $MixedArm64) {
    throw '-Arm64NativeArchive requires -MixedArm64.'
}
if ($MixedArm64 -and -not $SkipFlutterBuild -and -not $Arm64NativeArchive) {
    throw 'A local mixed ARM64 build requires -Arm64NativeArchive.'
}
if (-not $SkipFlutterBuild -and $flutterArchitecture -ne $hostArchitecture.ToLowerInvariant()) {
    throw "Cannot build Windows $Architecture on a $hostArchitecture host. Use -SkipFlutterBuild to package an existing bundle."
}
switch ($Architecture) {
    "x64" {
        $vcRedistName = "vc_redist.x64.exe"
        $vcRedistUrl = "https://aka.ms/vc14/vc_redist.x64.exe"
    }
    "arm64" {
        $vcRedistName = if ($MixedArm64) { "vc_redist.x64.exe" } else { "vc_redist.arm64.exe" }
        $vcRedistUrl = "https://aka.ms/vc14/$vcRedistName"
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

$buildDir = if ($BundlePath) {
    [IO.Path]::GetFullPath($BundlePath)
} elseif ($MixedArm64) {
    Join-Path $repoRoot "build\windows\arm64-mixed\runner\$Configuration"
} else {
    Join-Path $repoRoot "build\windows\$Architecture\runner\$Configuration"
}
if ($MixedArm64 -and $Arm64NativeArchive) {
    $metadataPath = Join-Path $repoRoot 'build\windows\metadata\build.json'
    & (Join-Path $repoRoot 'windows\build_scripts\Build-MetadataFile.ps1') `
        -Architecture x64 -OutputPath $metadataPath
    & (Join-Path $repoRoot 'windows\build_scripts\Prepare-MixedArm64Bundle.ps1') `
        -Configuration $Configuration `
        -Arm64NativeArchive $Arm64NativeArchive `
        -MetadataPath $metadataPath `
        -OutputBundle $buildDir
}
$bundleArchitecture = if ($MixedArm64) { 'arm64-mixed' } else { $Architecture }
if ($bundleArchitecture -in @('x64', 'arm64-mixed')) {
    & (Join-Path $repoRoot 'windows\build_scripts\Verify-WindowsBundle.ps1') `
        -BundlePath $buildDir -Architecture $bundleArchitecture -Configuration $Configuration
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
if ($MixedArm64) {
    $isccArguments = @('/DMixedArm64=1') + $isccArguments
}

& $isccPath @isccArguments
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE."
}

$installerName = if ($MixedArm64) { 'TrustTunnelSetup-arm64-mixed.exe' } else { "TrustTunnelSetup-$Architecture.exe" }
$installerPath = Join-Path $outputDir $installerName
if (-not (Test-Path $installerPath)) {
    throw "The installer was not created at the expected path: $installerPath"
}

Write-Host "Installer created: $installerPath" -ForegroundColor Green
