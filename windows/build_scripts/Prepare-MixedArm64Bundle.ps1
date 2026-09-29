# Creates an unsigned mixed ARM64 bundle from the x64 Flutter bundle.
# Uses the x64 CMake build metadata to select the matching ARM64 native ZIP,
# then replaces only the VPN service EXEs and wintun.dll. Verifies the result
# and records the ARM64 ZIP's SHA-256 alongside the x64 archive hash.
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Profile', 'Release')]
    [string]$Configuration = 'Release',

    [string]$Arm64NativeArchive,

    [string]$MetadataPath = 'build\windows\metadata\build.json',

    [string]$SourceBundle,

    [string]$OutputBundle
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $SourceBundle) {
    $SourceBundle = Join-Path $repoRoot "build\windows\x64\runner\$Configuration"
}
if (-not $OutputBundle) {
    $OutputBundle = Join-Path $repoRoot "build\windows\arm64-mixed\runner\$Configuration"
}
$SourceBundle = [IO.Path]::GetFullPath($SourceBundle)
$OutputBundle = [IO.Path]::GetFullPath($OutputBundle)
if ([string]::Equals($SourceBundle, $OutputBundle, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The mixed ARM64 output bundle must be separate from the x64 source bundle.'
}
if (-not [IO.Path]::IsPathRooted($MetadataPath)) {
    $MetadataPath = Join-Path $repoRoot $MetadataPath
}
if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
    throw "Windows build metadata is missing: $MetadataPath"
}
$metadata = Get-Content -LiteralPath $MetadataPath -Raw | ConvertFrom-Json
if ($metadata.architecture -ne 'x64' -or
    $metadata.trusttunnel_client.architecture -ne 'x86_64' -or
    $metadata.trusttunnel_client.archive_sha256 -notmatch '^[0-9a-fA-F]{64}$' -or
    [string]::IsNullOrWhiteSpace($metadata.trusttunnel_client.version)) {
    throw "Expected x64 TrustTunnel Client dependency metadata in $MetadataPath"
}
$clientVersion = $metadata.trusttunnel_client.version
$archiveName = "trusttunnel-client-windows-$clientVersion-aarch64.zip"

if ($Arm64NativeArchive) {
    if (-not (Test-Path -LiteralPath $Arm64NativeArchive -PathType Leaf)) {
        throw "ARM64 native archive is missing: $Arm64NativeArchive"
    }
    if ((Split-Path -Leaf $Arm64NativeArchive) -ne $archiveName) {
        throw "ARM64 native archive must match the x64 dependency version ${clientVersion}: $archiveName"
    }
} else {
    if ([string]::IsNullOrWhiteSpace($env:GPR_KEY)) {
        throw 'GPR_KEY is not set. Cannot download the ARM64 native archive.'
    }
    $downloadDir = Join-Path $repoRoot 'build\windows\arm64-mixed\downloads'
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    $Arm64NativeArchive = Join-Path $downloadDir $archiveName
    $packageUrl = "https://maven.pkg.github.com/TrustTunnel/TrustTunnelClient/com/adguard/trusttunnel/trusttunnel-client-windows/$clientVersion/$archiveName"
    $credential = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($env:GPR_KEY):"))
    try {
        Invoke-WebRequest -Uri $packageUrl -Headers @{ Authorization = "Basic $credential" } `
            -OutFile $Arm64NativeArchive -UseBasicParsing
    }
    catch {
        Remove-Item -LiteralPath $Arm64NativeArchive -ErrorAction SilentlyContinue
        throw "Failed to download ARM64 native archive $archiveName from GitHub Packages: $($_.Exception.Message)"
    }
}

& (Join-Path $PSScriptRoot 'Verify-WindowsBundle.ps1') `
    -BundlePath $SourceBundle -Architecture x64 -Configuration $Configuration

$stageRoot = Join-Path $repoRoot "build\windows\arm64-mixed\stage\$([guid]::NewGuid().ToString('N'))"
$nativeDirectory = Join-Path $stageRoot 'native'
New-Item -ItemType Directory -Path $nativeDirectory -Force | Out-Null
try {
    try {
        Expand-Archive -LiteralPath $Arm64NativeArchive -DestinationPath $nativeDirectory
    }
    catch {
        throw "Cannot extract ARM64 native archive ${Arm64NativeArchive}: $($_.Exception.Message)"
    }
    $nativeBin = Join-Path $nativeDirectory 'bin'
    foreach ($name in @('trusttunnel_service.exe', 'trusttunnel_service_installer.exe', 'wintun.dll')) {
        $path = Join-Path $nativeBin $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "ARM64 native package is missing: $path"
        }
    }

    if (Test-Path -LiteralPath $OutputBundle) {
        Remove-Item -LiteralPath $OutputBundle -Recurse -Force
    }
    New-Item -ItemType Directory -Path $OutputBundle -Force | Out-Null
    Copy-Item -Path (Join-Path $SourceBundle '*') -Destination $OutputBundle -Recurse -Force
    foreach ($name in @('trusttunnel_service.exe', 'trusttunnel_service_installer.exe', 'wintun.dll')) {
        Copy-Item -LiteralPath (Join-Path $nativeBin $name) `
            -Destination (Join-Path $OutputBundle $name) -Force
    }
    & (Join-Path $PSScriptRoot 'Verify-WindowsBundle.ps1') `
        -BundlePath $OutputBundle -Architecture arm64-mixed -Configuration $Configuration

    $arm64Sha256 = (Get-FileHash -LiteralPath $Arm64NativeArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    $metadata.trusttunnel_client | Add-Member -NotePropertyName arm64_archive_sha256 `
        -NotePropertyValue $arm64Sha256 -Force
    $metadata.trusttunnel_client | Add-Member -NotePropertyName arm64_architecture `
        -NotePropertyValue 'aarch64' -Force
    $metadataJson = $metadata | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($MetadataPath, $metadataJson, [Text.UTF8Encoding]::new($false))
    Write-Host "Prepared mixed ARM64 bundle: $OutputBundle"
}
finally {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
}
