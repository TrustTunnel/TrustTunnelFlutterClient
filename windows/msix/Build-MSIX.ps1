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
#   - Windows SDK (for MakeAppx via the msix plugin; signtool must be on PATH)
#   - Test cert generated: .\windows\msix\Setup-TestCert.ps1 (one-time)
#
# Flow:
#   1. flutter build windows
#   2. dart run msix:build        (generates AppxManifest + assets)
#   2b. Sign vpn.exe with the test cert and derive the client-authentication pin
#   3. Patch AppxManifest.xml: inject the packaged service
#   4. dart run msix:pack          (packages + signs with the test cert)
#
# Service logs after install:
#   C:\ProgramData\TrustTunnel\logs\service.log
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
    # 0. Detect host architecture; msix accepts only "x64" or "arm64".
    # ------------------------------------------------------------------
    $hostArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    $msixArch = if ($hostArch -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
        "arm64"
    } else {
        "x64"
    }
    Write-Host "  Host architecture: $msixArch" -ForegroundColor DarkGray

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
    dart run msix:build --$($Configuration.ToLower()) --architecture $msixArch
    if ($LASTEXITCODE -ne 0) {
        Write-Error "msix:build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    # Flutter build layout: build\windows\<arch>\runner\<Config>
    $buildOutputDir = Join-Path $PWD "build\windows\$msixArch\runner\$Configuration"
    if (-not (Test-Path $buildOutputDir)) {
        Write-Error "Build output not found under build\windows\$msixArch\runner\$Configuration. Did 'flutter build windows' succeed?"
        exit 1
    }

    # ------------------------------------------------------------------
    # 2b. Sign the app executable and derive the client-authentication pin
    # ------------------------------------------------------------------
    Write-Host "=== Signing app executable + deriving client pin ===" -ForegroundColor Cyan

    $appExePath = Join-Path $buildOutputDir "vpn.exe"
    if (-not (Test-Path $appExePath)) {
        Write-Error "App executable not found at '$appExePath'. Did 'flutter build windows' succeed?"
        exit 1
    }

    signtool sign /fd SHA256 /f $testPfxPath /p "trusttunnel" $appExePath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "signtool failed to sign '$appExePath' (exit code $LASTEXITCODE)"
        exit $LASTEXITCODE
    }

    $signerCert = (Get-AuthenticodeSignature -FilePath $appExePath).SignerCertificate
    if ($null -eq $signerCert) {
        Write-Error "App executable '$appExePath' has no signer certificate; refusing to build a pinless MSIX"
        exit 1
    }

    $clientPin = $signerCert.GetCertHashString([System.Security.Cryptography.HashAlgorithmName]::SHA256)
    if (-not $clientPin -or $clientPin.Length -ne 64) {
        Write-Error "Failed to derive a 64-character SHA-256 pin for '$appExePath' (got: '$clientPin')"
        exit 1
    }
    Write-Host "  App executable signed; client-authentication pin: $clientPin" -ForegroundColor Green

    # ------------------------------------------------------------------
    # 3. Locate and patch AppxManifest.xml IN-PLACE
    # ------------------------------------------------------------------
    Write-Host "=== Injecting packaged service extension ===" -ForegroundColor Cyan

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

    # <Extensions> must use the AppX default namespace or MakeAppx rejects it.
    $appxNs = $manifest.DocumentElement.NamespaceURI

    # Find or create <Extensions>
    $extensionsNode = $applicationNode.SelectSingleNode("*[local-name()='Extensions']")
    if (-not $extensionsNode) {
        $extensionsNode = $manifest.CreateElement("Extensions", $appxNs)
        $applicationNode.AppendChild($extensionsNode) | Out-Null
    }

    # Service arguments: logs dir, pipe name, ring buffer path, pin.
    # An empty pipe name makes the service generate a random one per start;
    # the plugin discovers it from the registry. The logs dir must match the
    # plugin's (%ProgramData%\TrustTunnel\logs).
    $serviceArgs = '%ProgramData%\TrustTunnel\logs "" %ProgramData%\TrustTunnel\vpn_query_log.ring {0}' -f $clientPin

    $d6ns = "http://schemas.microsoft.com/appx/manifest/desktop/windows10/6"
    $existingService = $extensionsNode.SelectSingleNode(
        "*[local-name()='Extension' and @Category='windows.service']")
    if (-not $existingService) {
        $svcExt = $manifest.CreateElement("desktop6", "Extension", $d6ns)
        $svcExt.SetAttribute("Category", "windows.service")
        $svcExt.SetAttribute("Executable", "trusttunnel_service.exe")
        $svcExt.SetAttribute("EntryPoint", "Windows.FullTrustApplication")

        $svc = $manifest.CreateElement("desktop6", "Service", $d6ns)
        $svc.SetAttribute("Name", "TrustTunnelVPN")
        $svc.SetAttribute("StartupType", "manual")
        $svc.SetAttribute("StartAccount", "localSystem")
        $svc.SetAttribute("Arguments", $serviceArgs)
        $svcExt.AppendChild($svc) | Out-Null

        $extensionsNode.AppendChild($svcExt) | Out-Null
        Write-Host "  Added packaged service: trusttunnel_service.exe (TrustTunnelVPN)" -ForegroundColor Green
        Write-Host "    Arguments: $serviceArgs" -ForegroundColor DarkGray
    } else {
        # msix:build regenerates the manifest on every run, so an existing
        # service extension means a stale or hand-edited manifest.
        Write-Error "AppxManifest.xml already contains a windows.service extension; expected a freshly generated manifest"
        exit 1
    }

    # The msix plugin does not list desktop6 in IgnorableNamespaces; add it.
    $root = $manifest.DocumentElement
    $ignorable = $root.GetAttribute("IgnorableNamespaces")
    if ($ignorable -notmatch "\bdesktop6\b") {
        $newIgnorable = if ($ignorable) { "$ignorable desktop6" } else { "desktop6" }
        $root.SetAttribute("IgnorableNamespaces", $newIgnorable)
    }

    $manifest.Save($manifestPath)
    Write-Host "  Manifest patched successfully." -ForegroundColor Green

    # ------------------------------------------------------------------
    # 3b. Drop the installer helper; the packaged service is managed by the platform.
    # ------------------------------------------------------------------
    $svcInstaller = Join-Path $buildOutputDir "trusttunnel_service_installer.exe"
    if (Test-Path $svcInstaller) {
        Remove-Item $svcInstaller -Force
        Write-Host "  Removed trusttunnel_service_installer.exe from MSIX staging (not needed for packaged service)" -ForegroundColor Green
    }

    # ------------------------------------------------------------------
    # 4. Package + sign
    # ------------------------------------------------------------------
    Write-Host "=== Packaging MSIX (test cert from msix_config) ===" -ForegroundColor Cyan

    $packArgs = @("run", "msix:pack", "--$($Configuration.ToLower())", "--architecture", $msixArch)
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
        $msixRelPath = "build\windows\$msixArch\runner\$Configuration\trusttunnel.msix"
    }
    Write-Host "    Add-AppxPackage -Path `".\$msixRelPath`"" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  --- VERIFY SERVICE ---" -ForegroundColor Yellow
    Write-Host '    Get-Service TrustTunnelVPN' -ForegroundColor Cyan
    Write-Host '    # Published pipe name (random per start):' -ForegroundColor White
    Write-Host '    Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\TrustTunnelVPN\Parameters" -Name PipeName' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  --- SERVICE LOGS ---" -ForegroundColor Yellow
    Write-Host '    # Service log file:' -ForegroundColor White
    Write-Host '    Get-Content C:\ProgramData\TrustTunnel\logs\service.log -Tail 50' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '    # Ring buffer log (binary):' -ForegroundColor White
    Write-Host '    Get-Item C:\ProgramData\TrustTunnel\vpn_query_log.ring' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '    # Windows Event Log:' -ForegroundColor White
    Write-Host '    Get-WinEvent -LogName Application | Where-Object { $_.ProviderName -match "TrustTunnelVPN" } | Select-Object -First 20' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  --- UNINSTALL ---" -ForegroundColor Yellow
    Write-Host '    Get-AppxPackage *trusttunnel* | Remove-AppxPackage' -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Green
}
finally {
    Pop-Location
}
