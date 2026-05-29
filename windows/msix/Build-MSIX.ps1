# Build-MSIX.ps1
# Builds a Windows MSIX package for TrustTunnel VPN.
#
# Usage:
#   First time setup (generates + trusts the test cert):
#     .\windows\msix\Setup-TestCert.ps1
#
#   Local dev (test cert):
#     .\windows\msix\Build-MSIX.ps1
#
#   Production (real code-signing cert):
#     .\windows\msix\Build-MSIX.ps1 -CertificatePath C:\ci\codesign.pfx
#     .\windows\msix\Build-MSIX.ps1 -CertificatePath C:\ci\codesign.pfx -CertificatePassword $env:SIGN_PASSWORD
#     .\windows\msix\Build-MSIX.ps1 -SignToolOptions "/sha1 A1B2C3... /fd SHA256 /tr http://timestamp.digicert.com /td SHA256"
#     .\windows\msix\Build-MSIX.ps1 -Publisher "CN=AdGuard, O=AdGuard Software Limited, C=CY"
#
#   CI/CD (Azure Key Vault — download cert first, then sign):
#     az keyvault secret download --vault-name MyVault --name CodeSigningCert --file cert.pfx
#     .\windows\msix\Build-MSIX.ps1 -CertificatePath cert.pfx -CertificatePassword $env:SIGN_PASSWORD
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
#   4. dart run msix:pack          (packages + signs)
#
# Signing:
#   - If -CertificatePath is given, it OVERRIDES the certificate_path /
#     certificate_password in pubspec.yaml for this build. The publisher
#     subject is auto-detected from the PFX file.
#   - If -SignToolOptions is given, those are passed verbatim to
#     SignTool.exe (useful for /sha1 store selection, CSP providers, etc.).
#   - If -Publisher is given, it OVERRIDES the publisher subject string.
#   - If none of these are given, the test cert in msix_config is used.
#     The test cert must be generated first via Setup-TestCert.ps1.
#
# Service logs after install:
#   C:\ProgramData\TrustTunnel\vpn_easy_service.log
#   C:\ProgramData\TrustTunnel\vpn_query_log.ring
#   Also viewable: Get-WinEvent -LogName Application | Where-Object { $_.ProviderName -match 'TrustTunnelVPN' }

param(
    [ValidateSet("Debug", "Profile", "Release")]
    [string]$Configuration = "Release",

    # Target CPU architecture for the MSIX package.
    # Must match the architecture used by `flutter build windows`.
    [ValidateSet("x64", "arm64", "x86")]
    [string]$Architecture = "x64",

    # Path to a .pfx code-signing certificate. Overrides pubspec.yaml certificate_path.
    [string]$CertificatePath,

    # Password for the .pfx file. Overrides pubspec.yaml certificate_password.
    [string]$CertificatePassword,

    # Raw SignTool.exe options (e.g. "/sha1 THUMBPRINT /fd SHA256 /tr http://timestamp.digicert.com /td SHA256").
    # When set, passed as --signtool-options to dart run msix:pack.
    [string]$SignToolOptions,

    # Publisher subject string (e.g. "CN=AdGuard, O=AdGuard Software Limited, C=CY").
    # Overrides pubspec.yaml publisher. Auto-detected from the PFX if not set
    # and -CertificatePath is provided.
    [string]$Publisher
)

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot\..\..

try {
    # ------------------------------------------------------------------
    # 0. Pre-check: test cert must exist when not using production signing
    # ------------------------------------------------------------------
    $testPfxPath = Join-Path $PSScriptRoot "test_cert.pfx"
    if (-not $CertificatePath -and -not $SignToolOptions -and -not (Test-Path $testPfxPath)) {
        Write-Host "Test certificate not found: $testPfxPath" -ForegroundColor Red
        Write-Host "Run this first to generate it:" -ForegroundColor Yellow
        Write-Host "  .\windows\msix\Setup-TestCert.ps1" -ForegroundColor Cyan
        Write-Host "Or specify a production cert: -CertificatePath <path>" -ForegroundColor Yellow
        exit 1
    }

    # ------------------------------------------------------------------
    # 1. Flutter build
    # ------------------------------------------------------------------
    Write-Host "=== Building Flutter Windows app ($Configuration) ===" -ForegroundColor Cyan
    flutter build windows --$($Configuration.ToLower())

    # ------------------------------------------------------------------
    # 2. Generate MSIX files (manifest + assets, no packaging yet)
    # ------------------------------------------------------------------
    Write-Host "=== Generating MSIX assets (msix:build) ===" -ForegroundColor Cyan
    dart run msix:build --$($Configuration.ToLower())

    # ------------------------------------------------------------------
    # 3. Locate and patch AppxManifest.xml IN-PLACE
    # ------------------------------------------------------------------
    Write-Host "=== Injecting packaged service extension ===" -ForegroundColor Cyan

    # The msix plugin writes the manifest next to the built exe.
    $buildConfigDir = switch ($Configuration) {
        "Debug"   { "Debug" }
        "Profile" { "Profile" }
        "Release" { "Release" }
    }

    $manifestPath = Join-Path $PWD "build\windows\runner\$buildConfigDir\AppxManifest.xml"

    if (-not (Test-Path $manifestPath)) {
        # Fallback: search recursively (covers older layouts)
        $found = Get-ChildItem -Path "build\windows" -Recurse -Filter "AppxManifest.xml" |
            Select-Object -First 1
        if ($found) {
            $manifestPath = $found.FullName
        } else {
            Write-Error "Could not find AppxManifest.xml under build\windows"
            exit 1
        }
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

    # Ensure desktop6 is in IgnorableNamespaces (msix plugin may already add it)
    $root = $manifest.DocumentElement
    $ignorable = $root.GetAttribute("IgnorableNamespaces")
    if ($ignorable -notmatch "\bdesktop6\b") {
        $root.SetAttribute("IgnorableNamespaces", "$ignorable desktop6")
    }

    $manifest.Save($manifestPath)
    Write-Host "  Manifest patched successfully." -ForegroundColor Green

    # ------------------------------------------------------------------
    # 3b. Remove service_installer.exe from the staging directory
    #     (not needed in MSIX — the packaged service is managed by the
    #      platform via desktop6:Service; service_installer.exe is only
    #      used by the non-MSIX elevated helper path).
    # ------------------------------------------------------------------
    $stagingDir = $buildOutputDir
    $svcInstaller = Join-Path $stagingDir "service_installer.exe"
    if (Test-Path $svcInstaller) {
        Remove-Item $svcInstaller -Force
        Write-Host "  Removed service_installer.exe from MSIX staging (not needed for packaged service)" -ForegroundColor Green
    }

    # ------------------------------------------------------------------
    # 4. Package + sign
    # ------------------------------------------------------------------
    # Build the dart run msix:pack command, optionally overriding
    # the certificate / publisher / signtool options from pubspec.yaml.

    $packArgs = @("run", "msix:pack", "--$($Configuration.ToLower())")

    if ($CertificatePath) {
        $packArgs += @("--certificate-path", $CertificatePath)
        if ($CertificatePassword) {
            $packArgs += @("--certificate-password", $CertificatePassword)
        }
        Write-Host "=== Packaging MSIX with production cert: $CertificatePath ===" -ForegroundColor Cyan
    }
    elseif ($SignToolOptions) {
        $packArgs += @("--signtool-options", $SignToolOptions)
        Write-Host "=== Packaging MSIX with custom SignTool options ===" -ForegroundColor Cyan
    }
    else {
        Write-Host "=== Packaging MSIX (test cert from msix_config) ===" -ForegroundColor Cyan
    }

    if ($Publisher) {
        $packArgs += @("--publisher", $Publisher)
    }

    Write-Host "  Command: dart $($packArgs -join ' ')" -ForegroundColor DarkGray
    & dart @packArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "msix:pack failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    # ------------------------------------------------------------------
    # 5. Summary & install instructions
    # ------------------------------------------------------------------
    $msixFile = Get-ChildItem -Path "build\windows\runner\$buildConfigDir" -Filter "*.msix" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    $isTestCert = -not $CertificatePath -and -not $SignToolOptions

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "  MSIX package created successfully!" -ForegroundColor Green
    if ($msixFile) {
        Write-Host "  File: $($msixFile.FullName)" -ForegroundColor White
        Write-Host "  Size: $([math]::Round($msixFile.Length / 1MB, 1)) MB" -ForegroundColor White
    }
    if ($isTestCert) {
        Write-Host ""
        Write-Host "  Signed with TEST certificate (CN=TrustTunnelDev)." -ForegroundColor Yellow
        Write-Host "  For local testing only — the cert must be trusted on the target machine." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  If you haven't trusted the cert yet, run:" -ForegroundColor Yellow
        Write-Host '    .\windows\msix\Setup-TestCert.ps1' -ForegroundColor Cyan
    }
    else {
        Write-Host ""
        Write-Host "  Signed with PRODUCTION certificate." -ForegroundColor Green
        Write-Host "  Ensure the cert chain is trusted on the target machine." -ForegroundColor White
    }
    Write-Host ""
    Write-Host "  --- INSTALL ---" -ForegroundColor Yellow
    Write-Host '    Add-AppxPackage -Path ".\build\windows\runner\'$buildConfigDir'\trusttunnel.msix"' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  --- VERIFY SERVICE ---" -ForegroundColor Yellow
    Write-Host '    Get-Service TrustTunnelVPN' -ForegroundColor Cyan
    Write-Host '    Start-Service TrustTunnelVPN' -ForegroundColor Cyan
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
