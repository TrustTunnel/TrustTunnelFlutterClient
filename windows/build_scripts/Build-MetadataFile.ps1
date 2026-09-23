[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('x64', 'arm64')]
    [string]$Architecture,

    [string]$OutputPath = "build\windows\metadata\build.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-CMakeCacheValue {
    param(
        [string]$Cache,
        [string]$Name
    )

    $pattern = "(?m)^$([regex]::Escape($Name)):[^=]+=(.*?)\r?$"
    $match = [regex]::Match($Cache, $pattern)
    if (
        -not $match.Success -or
        [string]::IsNullOrWhiteSpace($match.Groups[1].Value)
    ) {
        throw "CMake cache value '$Name' is missing."
    }
    return $match.Groups[1].Value.Trim()
}

$flutterJson = (& flutter --version --machine | Out-String) |
    ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Could not determine the Flutter and Dart versions."
}

$cmakeCache = Get-Content "build\windows\$Architecture\CMakeCache.txt" -Raw
$cmakeCommand = Get-CMakeCacheValue $cmakeCache "CMAKE_COMMAND"
$compilerPath = Get-CMakeCacheValue $cmakeCache "CMAKE_CXX_COMPILER"

$cmakeOutput = & $cmakeCommand --version
if ($LASTEXITCODE -ne 0) {
    throw "Could not determine the CMake version."
}
$cmakeMatch = [regex]::Match(
    ($cmakeOutput -join "`n"),
    "cmake version\s+(\S+)"
)
if (-not $cmakeMatch.Success) {
    throw "Could not parse the CMake version."
}

$vswherePath = Join-Path `
    ${env:ProgramFiles(x86)} `
    "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswherePath -PathType Leaf)) {
    throw "vswhere.exe was not found."
}
$visualStudioInstances = (& $vswherePath `
    -all `
    -products * `
    -format json `
    -utf8 | Out-String) | ConvertFrom-Json
$visualStudioInstance = $visualStudioInstances |
    Where-Object {
        $compilerPath.StartsWith(
            $_.installationPath,
            [StringComparison]::OrdinalIgnoreCase
        )
    } |
    Select-Object -First 1
if (
    $LASTEXITCODE -ne 0 -or
    $null -eq $visualStudioInstance -or
    [string]::IsNullOrWhiteSpace(
        $visualStudioInstance.installationVersion
    )
) {
    throw "Could not determine the Visual Studio version."
}

$clientVersion = Get-CMakeCacheValue `
    $cmakeCache `
    "TRUSTTUNNEL_CLIENT_RESOLVED_VERSION"
$clientArchitecture = Get-CMakeCacheValue `
    $cmakeCache `
    "TRUSTTUNNEL_CLIENT_RESOLVED_ARCH"
$clientArchivePath = Get-CMakeCacheValue `
    $cmakeCache `
    "TRUSTTUNNEL_CLIENT_ARCHIVE_PATH"
$clientArchiveSha256 = Get-CMakeCacheValue `
    $cmakeCache `
    "TRUSTTUNNEL_CLIENT_ARCHIVE_SHA256"
if ($clientArchiveSha256 -notmatch "^[0-9a-fA-F]{64}$") {
    throw "The TrustTunnel Client archive SHA-256 is invalid."
}
if (-not (Test-Path -LiteralPath $clientArchivePath -PathType Leaf)) {
    throw "TrustTunnel Client archive is missing: $clientArchivePath"
}
$actualClientArchiveSha256 = (
    Get-FileHash -LiteralPath $clientArchivePath -Algorithm SHA256
).Hash
if (-not [string]::Equals(
    $actualClientArchiveSha256,
    $clientArchiveSha256,
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "TrustTunnel Client archive SHA-256 differs from CMake."
}

$metadata = [ordered]@{
    architecture = $Architecture
    flutter_version = $flutterJson.frameworkVersion
    dart_version = $flutterJson.dartSdkVersion
    cmake_version = $cmakeMatch.Groups[1].Value
    visual_studio_version = $visualStudioInstance.installationVersion.Trim()
    trusttunnel_client = [ordered]@{
        version = $clientVersion
        architecture = $clientArchitecture
        archive_sha256 = $clientArchiveSha256.ToLowerInvariant()
    }
}

$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory `
    -Path (Split-Path $outputFullPath -Parent) `
    -Force | Out-Null
$metadataJson = $metadata | ConvertTo-Json -Depth 5
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($outputFullPath, $metadataJson, $utf8NoBom)

Write-Host "Windows build metadata created: $outputFullPath" -ForegroundColor Green
