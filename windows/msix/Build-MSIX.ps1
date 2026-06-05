# Build-MSIX.ps1
# Builds a Windows MSIX package for TrustTunnel VPN (dev/test only).
#
# Usage:
#   First time setup (generates + trusts the test cert):
#     .\windows\msix\Setup-TestCert.ps1
#
#   Build:
#     .\windows\msix\Build-MSIX.ps1
#
# Prerequisites:
#   - Flutter SDK
#   - Windows SDK (for MakeAppx / SignTool, pulled in by the msix plugin)
#   - Test cert generated: .\windows\msix\Setup-TestCert.ps1 (one-time)
#
# Flow:
#   1. flutter build windows
#   2. dart run msix:build        (generates AppxManifest + assets)
#   3. Patch AppxManifest.xml: inject packaged service extension
#      so Windows auto-installs vpn_easy_service.exe as SYSTEM
#   4. dart run msix:pack          (packages + signs with test cert)
#
# Service logs after install:
#   C:\ProgramData\TrustTunnel\vpn_easy_service.log
#   C:\ProgramData\TrustTunnel\vpn_query_log.ring
#   Also viewable: Get-WinEvent -LogName Application | Where-Object { $_.ProviderName -match 'TrustTunnelVPN' }

param(
    [ValidateSet("Debug", "Profile", "Release")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..\..

try {
    # ------------------------------------------------------------------
    # 0. Pre-check: test cert must exist
    # ------------------------------------------------------------------
    $testPfxPath = Join-Path $PSScriptRoot "test_cert.pfx"
    if (-not (Test-Path $testPfxPath)) {
        Write-Host "Test certificate not found: $testPfxPath" -ForegroundColor Red
        Write-Host "Run this first to generate it:" -ForegroundColor Yellow
        Write-Host "  .\windows\msix\Setup-TestCert.ps1" -ForegroundColor Cyan
        exit 1
    }

    # ------------------------------------------------------------------
    # 1. Flutter build
    # ------------------------------------------------------------------
    Write-Host "=== Building Flutter Windows app ($Configuration) ===" -ForegroundColor Cyan
    flutter build windows --$($Configuration.ToLower())
    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter build windows failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    # ------------------------------------------------------------------
    # 2. Generate MSIX files (manifest + assets, no packaging yet)
    # ------------------------------------------------------------------
    Write-Host "=== Generating MSIX assets (msix:build) ===" -ForegroundColor Cyan
    dart run msix:build --$($Configuration.ToLower())
    if ($LASTEXITCODE -ne 0) {
        Write-Error "msix:build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    # ------------------------------------------------------------------
    # 3. Locate and patch AppxManifest.xml IN-PLACE
    # ------------------------------------------------------------------
    Write-Host "=== Injecting packaged service extension ===" -ForegroundColor Cyan

    # The msix plugin writes the manifest next to the built exe.
    # Flutter build layout: build\windows\<arch>\runner\<Config>
    # Cross-compilation is not supported, so there will only ever be one
    # architecture directory matching the host platform.

    # Detect the architecture directory produced by the build.
    $buildOutputDir = $null
    foreach ($arch in @("x64", "arm64", "x86")) {
        $candidate = Join-Path $PWD "build\windows\$arch\runner\$Configuration"
        if (Test-Path $candidate) {
            $buildOutputDir = $candidate
            break
        }
    }
    if (-not $buildOutputDir) {
        Write-Error "Build output not found under build\windows\*\runner\$Configuration. Did 'flutter build windows' succeed?"
        exit 1
    }

    $manifestPath = Join-Path $buildOutputDir "AppxManifest.xml"

    if (-not (Test-Path $manifestPath)) {
        Write-Error "AppxManifest.xml not found at '$manifestPath'. Did 'dart run msix:build' succeed?"
        exit 1
    }

    Write-Host "  Manifest: $manifestPath" -ForegroundColor Green

    [xml]$manifest = Get-Content $manifestPath

    # Find <Application> node
    $applicationNode = $manifest.SelectSingleNode("//*[local-name()='Application']")
    if (-not $applicationNode) {
        Write-Error "No <Application> node found in manifest"
        exit 1
    }

    # The <Extensions> element must be in the default AppX namespace
    # (http://schemas.microsoft.com/appx/manifest/foundation/windows10),
    # otherwise MakeAppx rejects the manifest.
    $appxNs = $manifest.DocumentElement.NamespaceURI

    # Find or create <Extensions>
    $extensionsNode = $applicationNode.SelectSingleNode("*[local-name()='Extensions']")
    if (-not $extensionsNode) {
        $extensionsNode = $manifest.CreateElement("Extensions", $appxNs)
        $applicationNode.AppendChild($extensionsNode) | Out-Null
    }

    # Inject the packaged service extension — declares vpn_easy_service.exe
    # as a Windows service (LocalSystem) that Windows auto-installs with the MSIX.
    # Arguments must match pipe_name_ and ring_buffer_path_ in vpn_plugin.cpp.
    # StartupType="manual" because the app connects via named pipe on-demand.
    $serviceArgs = "%ProgramData%\TrustTunnel\vpn_easy_service.log \\.\pipe\trusttunnel_vpn %ProgramData%\TrustTunnel\vpn_query_log.ring"

    $d6ns = "http://schemas.microsoft.com/appx/manifest/desktop/windows10/6"
    $existingService = $extensionsNode.SelectSingleNode(
        "*[local-name()='Extension' and @Category='windows.service']")
    if (-not $existingService) {
        $svcExt = $manifest.CreateElement("desktop6", "Extension", $d6ns)
        $svcExt.SetAttribute("Category", "windows.service")
        $svcExt.SetAttribute("Executable", "vpn_easy_service.exe")
        $svcExt.SetAttribute("EntryPoint", "Windows.FullTrustApplication")

        $svc = $manifest.CreateElement("desktop6", "Service", $d6ns)
        $svc.SetAttribute("Name", "TrustTunnelVPN")
        $svc.SetAttribute("StartupType", "manual")
        $svc.SetAttribute("StartAccount", "localSystem")
        $svc.SetAttribute("Arguments", $serviceArgs)
        $svcExt.AppendChild($svc) | Out-Null

        $extensionsNode.AppendChild($svcExt) | Out-Null
        Write-Host "  Added packaged service: vpn_easy_service.exe (TrustTunnelVPN)" -ForegroundColor Green
        Write-Host "    Arguments: $serviceArgs" -ForegroundColor DarkGray
    } else {
        Write-Host "  Service extension already present — skipping injection" -ForegroundColor Yellow
    }

    # Ensure desktop6 is in IgnorableNamespaces.
    # The msix plugin already declares xmlns:desktop6 on the root element but
    # only puts "uap3 desktop" in IgnorableNamespaces, so we must add desktop6.
    $root = $manifest.DocumentElement
    $ignorable = $root.GetAttribute("IgnorableNamespaces")
    if ($ignorable -notmatch "\bdesktop6\b") {
        $newIgnorable = if ($ignorable) { "$ignorable desktop6" } else { "desktop6" }
        $root.SetAttribute("IgnorableNamespaces", $newIgnorable)
    }

    $manifest.Save($manifestPath)
    Write-Host "  Manifest patched successfully." -ForegroundColor Green

    # ------------------------------------------------------------------
    # 3b. Remove service_installer.exe from the staging directory
    #     (not needed in MSIX — the packaged service is managed by the
    #      platform via desktop6:Service; service_installer.exe is only
    #      used by the non-MSIX elevated helper path).
    # ------------------------------------------------------------------
    $svcInstaller = Join-Path $buildOutputDir "service_installer.exe"
    if (Test-Path $svcInstaller) {
        Remove-Item $svcInstaller -Force
        Write-Host "  Removed service_installer.exe from MSIX staging (not needed for packaged service)" -ForegroundColor Green
    }

    # ------------------------------------------------------------------
    # 4. Package + sign
    # ------------------------------------------------------------------
    Write-Host "=== Packaging MSIX (test cert from msix_config) ===" -ForegroundColor Cyan

    $packArgs = @("run", "msix:pack", "--$($Configuration.ToLower())")
    Write-Host "  Command: dart $($packArgs -join ' ')" -ForegroundColor DarkGray
    & dart @packArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "msix:pack failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    # ------------------------------------------------------------------
    # 5. Summary & install instructions
    # ------------------------------------------------------------------
    $msixFile = Get-ChildItem -Path $buildOutputDir -Filter "*.msix" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "  MSIX package created successfully!" -ForegroundColor Green
    if ($msixFile) {
        $msixRelPath = $msixFile.FullName.Substring($PWD.Path.Length + 1)
    } else {
        $msixRelPath = "build\windows\x64\runner\$Configuration\trusttunnel.msix"
    }
    Write-Host "    Add-AppxPackage -Path `".\$msixRelPath`"" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  --- VERIFY SERVICE ---" -ForegroundColor Yellow
    Write-Host '    Get-Service TrustTunnelVPN' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  --- SERVICE LOGS ---" -ForegroundColor Yellow
    Write-Host '    # Service log file (the first service argument):' -ForegroundColor White
    Write-Host '    Get-Content C:\ProgramData\TrustTunnel\vpn_easy_service.log -Tail 50' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '    # Ring buffer log (binary, use the query tool or just check size):' -ForegroundColor White
    Write-Host '    Get-Item C:\ProgramData\TrustTunnel\vpn_query_log.ring' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '    # Windows Event Log (if service writes there via ReportEvent):' -ForegroundColor White
    Write-Host '    Get-WinEvent -LogName Application | Where-Object { $_.ProviderName -match "TrustTunnelVPN" } | Select-Object -First 20' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  --- UNINSTALL ---" -ForegroundColor Yellow
    Write-Host '    Get-AppxPackage *trusttunnel* | Remove-AppxPackage' -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Green
}
finally {
    Pop-Location
}
