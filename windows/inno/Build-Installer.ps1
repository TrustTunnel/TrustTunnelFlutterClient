# Builds one installer containing the x64 Flutter client and both native
# service variants with Inno Setup 6.6+.
# Arguments:
#   -Configuration          Flutter build configuration (default: Release).
#   -AppVersion             App version embedded in the installer.
#   -BuildNumber            Fourth component of the installer version.
#   -SkipFlutterBuild       Package existing bundles without building Flutter.
#   -Arm64NativeArchive     Use a local ARM64 native ZIP instead of downloading it.
#   -X64BundlePath          Path to the x64 Flutter bundle.
#   -MixedArm64BundlePath   Path to the mixed ARM64 bundle.
#   -ForceDownload          Download the VC++ redistributable again.
# Usage:
# From the repository root on x64 Windows (Flutter and GPR_KEY required):
#   .\windows\inno\Build-Installer.ps1 -Arm64NativeArchive <path-to-aarch64-zip>
# To package existing bundles:
#   .\windows\inno\Build-Installer.ps1 -SkipFlutterBuild -X64BundlePath <path> -MixedArm64BundlePath <path>

[CmdletBinding()]
param(
    [ValidateSet("Debug", "Profile", "Release")]
    [string]$Configuration = "Release",

    [ValidatePattern("^\d+\.\d+\.\d+([\-+][0-9A-Za-z.-]+)?$")]
    [string]$AppVersion = "1.2.0",

    [ValidateRange(0, 65535)]
    [int]$BuildNumber = 0,

    [switch]$SkipFlutterBuild,

    [string]$Arm64NativeArchive,

    [string]$X64BundlePath,

    [string]$MixedArm64BundlePath,

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

if (-not $SkipFlutterBuild -and
    [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {
    throw 'The x64 Flutter bundle must be built on x64 Windows. Use -SkipFlutterBuild to package existing bundles.'
}
$vcRedistName = 'vc_redist.x64.exe'
$vcRedistUrl = 'https://aka.ms/vc14/vc_redist.x64.exe'

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

$x64BuildDir = if ($X64BundlePath) {
    [IO.Path]::GetFullPath($X64BundlePath)
} else {
    Join-Path $repoRoot "build\windows\x64\runner\$Configuration"
}
$mixedBuildDir = if ($MixedArm64BundlePath) {
    [IO.Path]::GetFullPath($MixedArm64BundlePath)
} else {
    Join-Path $repoRoot "build\windows\arm64-mixed\runner\$Configuration"
}
if ([string]::Equals($x64BuildDir, $mixedBuildDir, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The x64 and mixed ARM64 bundles must have separate paths.'
}
if (-not $SkipFlutterBuild -or $Arm64NativeArchive) {
    $metadataPath = Join-Path $repoRoot 'build\windows\metadata\build.json'
    & (Join-Path $repoRoot 'windows\build_scripts\Build-MetadataFile.ps1') `
        -Architecture x64 -OutputPath $metadataPath
    & (Join-Path $repoRoot 'windows\build_scripts\Prepare-MixedArm64Bundle.ps1') `
        -Configuration $Configuration `
        -Arm64NativeArchive $Arm64NativeArchive `
        -SourceBundle $x64BuildDir `
        -MetadataPath $metadataPath `
        -OutputBundle $mixedBuildDir
}
foreach ($bundle in @(
    @{ Path = $x64BuildDir; Architecture = 'x64' },
    @{ Path = $mixedBuildDir; Architecture = 'arm64-mixed' }
)) {
    if (-not (Test-Path -LiteralPath $bundle.Path -PathType Container)) {
        throw "Windows $($bundle.Architecture) bundle is missing: $($bundle.Path)"
    }
    & (Join-Path $repoRoot 'windows\build_scripts\Verify-WindowsBundle.ps1') `
        -BundlePath $bundle.Path -Architecture $bundle.Architecture -Configuration $Configuration
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
    "/DX64BuildDir=$x64BuildDir",
    "/DMixedArm64BuildDir=$mixedBuildDir",
    "/DOutputDir=$outputDir",
    "/DVcRedistPath=$vcRedistPath",
    $issPath
)
& $isccPath @isccArguments
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE."
}

$installerPath = Join-Path $outputDir 'TrustTunnelSetup.exe'
if (-not (Test-Path $installerPath)) {
    throw "The installer was not created at the expected path: $installerPath"
}

Write-Host "Installer created: $installerPath" -ForegroundColor Green
