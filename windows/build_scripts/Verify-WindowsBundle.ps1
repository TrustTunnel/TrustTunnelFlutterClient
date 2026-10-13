# Verifies an x64 or mixed ARM64 Windows bundle during build or before packaging.
# Checks required files, PE architectures and the x64 Flutter AOT binary;
# in a mixed bundle, only the VPN service EXEs and wintun.dll must be ARM64.
# After signing, pass SignToolPath to verify every EXE and DLL signature too.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BundlePath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('x64', 'arm64-mixed')]
    [string]$Architecture,

    [ValidateSet('Debug', 'Profile', 'Release')]
    [string]$Configuration = 'Release',

    [string]$SignToolPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-PeMachine([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = [System.IO.BinaryReader]::new($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) { throw "Invalid PE file: $Path" }
        $stream.Position = 0x3C
        $peOffset = $reader.ReadInt32()
        if ($peOffset -lt 64 -or $peOffset -gt $stream.Length - 6) {
            throw "Invalid PE header offset: $Path"
        }
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) { throw "Invalid PE signature: $Path" }
        return $reader.ReadUInt16()
    }
    finally { $stream.Dispose() }
}

$requiredItems = @(
    'TrustTunnel.exe',
    'cleanup_user_data_helper.exe',
    'app_links_plugin.dll',
    'flutter_windows.dll',
    'screen_retriever_windows_plugin.dll',
    'sqlite3.dll',
    'sqlite3_flutter_libs_plugin.dll',
    'url_launcher_windows_plugin.dll',
    'vpn_plugin_plugin.dll',
    'window_manager_plugin.dll',
    'trusttunnel.dll',
    'trusttunnel_service.exe',
    'trusttunnel_service_installer.exe',
    'wintun.dll',
    'WINTUN_LICENSE.txt',
    'data\icudtl.dat',
    'data\flutter_assets'
)
if ($Configuration -ne 'Debug') { $requiredItems += 'data\app.so' }
foreach ($item in $requiredItems) {
    $path = Join-Path $BundlePath $item
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required Windows bundle item is missing: $path"
    }
}

$arm64Names = @('trusttunnel_service.exe', 'trusttunnel_service_installer.exe', 'wintun.dll')
$bundleRoot = (Resolve-Path -LiteralPath $BundlePath).Path
$binaries = @(Get-ChildItem -LiteralPath $BundlePath -Recurse -File |
    Where-Object { $_.Extension -in @('.exe', '.dll') })
foreach ($binary in $binaries) {
    $expectedMachine = if (
        $Architecture -eq 'arm64-mixed' -and
        $binary.DirectoryName -eq $bundleRoot -and
        $binary.Name -in $arm64Names
    ) { 0xAA64 } else { 0x8664 }
    if ((Get-PeMachine $binary.FullName) -ne $expectedMachine) {
        $expectedName = if ($expectedMachine -eq 0xAA64) { 'ARM64' } else { 'x64' }
        throw "Expected $expectedName PE binary: $($binary.FullName)"
    }
    if ($SignToolPath) {
        & $SignToolPath verify /pa /all /v /tw $binary.FullName
        if ($LASTEXITCODE -ne 0) {
            throw "Authenticode verification failed for $($binary.FullName)"
        }
    }
}

if ($Configuration -ne 'Debug') {
    $aotPath = Join-Path $BundlePath 'data\app.so'
    $aotStream = [System.IO.File]::OpenRead($aotPath)
    try {
        $aotReader = [System.IO.BinaryReader]::new($aotStream)
        if ($aotReader.ReadUInt32() -ne 0x464C457F) { throw "Invalid Flutter AOT file: $aotPath" }
        $aotStream.Position = 0x12
        if ($aotReader.ReadUInt16() -ne 0x3E) { throw "Expected x86-64 Flutter AOT file: $aotPath" }
    }
    finally { $aotStream.Dispose() }
}

Write-Host "Verified $Architecture Windows bundle: $BundlePath"
