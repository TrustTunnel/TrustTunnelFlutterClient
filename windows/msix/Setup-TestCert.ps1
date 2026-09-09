# Setup-TestCert.ps1
# Manages the self-signed test certificate for MSIX local development.
#
# Usage:
#   .\windows\msix\Setup-TestCert.ps1                 # Generate + trust (first time)
#   .\windows\msix\Setup-TestCert.ps1 -Untrust        # Remove from trusted roots
#   .\windows\msix\Setup-TestCert.ps1 -Remove         # Remove trust + delete cert files
#   .\windows\msix\Setup-TestCert.ps1 -Force          # Regenerate even if files exist
#
# What it does (default / generate mode):
#   1. Creates a self-signed certificate with subject CN=TrustTunnelDev
#      (must match `publisher` in pubspec.yaml msix_config).
#   2. Exports public key → test_cert.cer (for trusting)
#   3. Exports private key → test_cert.pfx (for signing, password: "trusttunnel")
#   4. Imports the .cer into LocalMachine\Root (requires admin)
#
# The .pfx/.cer files are NOT committed to git — each developer runs this once.

param(
    # Remove the certificate from the Local Machine Trusted Root store.
    [switch]$Untrust,

    # Remove trust AND delete the .pfx/.cer files from disk.
    [switch]$Remove,

    # Regenerate the certificate even if .pfx/.cer already exist.
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# --- Config (must match pubspec.yaml msix_config) ---
$CertSubject   = "CN=TrustTunnelDev"
$CertPassword  = "trusttunnel"
$FriendlyName  = "TrustTunnel MSIX Test Signing"
$ValidityYears = 2

$PfxPath = Join-Path $PSScriptRoot "test_cert.pfx"
$CerPath = Join-Path $PSScriptRoot "test_cert.cer"

# -------------------------------------------------------------------------
# Helper: ensure we're running as Administrator
# -------------------------------------------------------------------------
function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "This operation requires Administrator privileges." -ForegroundColor Red
        Write-Host "Re-launching as Administrator..." -ForegroundColor Yellow
        $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath)
        if ($Untrust)  { $args += "-Untrust" }
        if ($Remove)   { $args += "-Remove" }
        if ($Force)    { $args += "-Force" }
        Start-Process powershell -Verb runAs -ArgumentList $args
        exit
    }
}

# -------------------------------------------------------------------------
# Helper: find certificate by subject in LocalMachine\Root
# -------------------------------------------------------------------------
function Find-TrustedCert {
    return Get-ChildItem Cert:\LocalMachine\Root |
        Where-Object { $_.Subject -eq $CertSubject }
}

# -------------------------------------------------------------------------
# Helper: find certificate by subject in CurrentUser\My
# -------------------------------------------------------------------------
function Find-PersonalCert {
    return Get-ChildItem Cert:\CurrentUser\My |
        Where-Object { $_.Subject -eq $CertSubject }
}

# =========================================================================
# UNTRUST mode
# =========================================================================
if ($Untrust -or $Remove) {
    Assert-Admin

    # Remove from LocalMachine\Root (trusted roots)
    $trusted = Find-TrustedCert
    if ($trusted) {
        foreach ($c in $trusted) {
            Write-Host "Removing from Trusted Roots: $($c.Subject) ($($c.Thumbprint))" -ForegroundColor Cyan
            Remove-Item "Cert:\LocalMachine\Root\$($c.Thumbprint)" -Force
        }
        Write-Host "Certificate removed from Trusted Roots." -ForegroundColor Green
    } else {
        Write-Host "No trusted certificate with subject '$CertSubject' found." -ForegroundColor Yellow
    }

    if (-not $Remove) {
        exit 0
    }

    # Also remove from CurrentUser\My (personal store where New-SelfSignedCertificate puts it)
    $personal = Find-PersonalCert
    if ($personal) {
        foreach ($c in $personal) {
            Write-Host "Removing from Personal store: $($c.Subject) ($($c.Thumbprint))" -ForegroundColor Cyan
            Remove-Item "Cert:\CurrentUser\My\$($c.Thumbprint)" -Force
        }
        Write-Host "Certificate removed from Personal store." -ForegroundColor Green
    }

    # Delete files
    $deleted = $false
    if (Test-Path $PfxPath) {
        Remove-Item $PfxPath -Force
        Write-Host "Deleted: $PfxPath" -ForegroundColor Cyan
        $deleted = $true
    }
    if (Test-Path $CerPath) {
        Remove-Item $CerPath -Force
        Write-Host "Deleted: $CerPath" -ForegroundColor Cyan
        $deleted = $true
    }
    if ($deleted) {
        Write-Host "Certificate files removed." -ForegroundColor Green
    } else {
        Write-Host "No certificate files found on disk." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Cleanup complete. Run this script without flags to regenerate." -ForegroundColor Green
    exit 0
}

# =========================================================================
# GENERATE + TRUST mode (default)
# =========================================================================
Assert-Admin

# Check if files already exist and skip generation unless -Force
if ((Test-Path $PfxPath) -and (Test-Path $CerPath) -and -not $Force) {
    Write-Host "Certificate files already exist:" -ForegroundColor Yellow
    Write-Host "  PFX: $PfxPath" -ForegroundColor White
    Write-Host "  CER: $CerPath" -ForegroundColor White
    Write-Host "  Use -Force to regenerate, or -Remove to delete." -ForegroundColor DarkGray
} else {
    # Remove old cert from stores if regenerating
    if ($Force) {
        $oldTrusted = Find-TrustedCert
        foreach ($c in $oldTrusted) {
            Remove-Item "Cert:\LocalMachine\Root\$($c.Thumbprint)" -Force -ErrorAction SilentlyContinue
        }
        $oldPersonal = Find-PersonalCert
        foreach ($c in $oldPersonal) {
            Remove-Item "Cert:\CurrentUser\My\$($c.Thumbprint)" -Force -ErrorAction SilentlyContinue
        }
        Write-Host "Removed old certificates from stores." -ForegroundColor DarkGray
    }

    # Generate new self-signed certificate
    Write-Host "Generating test certificate..." -ForegroundColor Cyan
    Write-Host "  Subject:   $CertSubject" -ForegroundColor White
    Write-Host "  Valid for: $ValidityYears years" -ForegroundColor White

    $cert = New-SelfSignedCertificate `
        -Type Custom `
        -Subject $CertSubject `
        -KeyUsage DigitalSignature `
        -FriendlyName $FriendlyName `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -TextExtension @(
            "2.5.29.37={text}1.3.6.1.5.5.7.3.3",     # Code Signing EKU
            "2.5.29.19={text}"                          # Basic Constraints (not a CA)
        ) `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddYears($ValidityYears)

    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor White

    # Export private key as .pfx (for signing)
    $securePwd = ConvertTo-SecureString -String $CertPassword -Force -AsPlainText
    Export-PfxCertificate -Cert $cert -FilePath $PfxPath -Password $securePwd | Out-Null
    Write-Host "  Exported:   $PfxPath" -ForegroundColor Green

    # Export public key as .cer (for trusting)
    Export-Certificate -Cert $cert -FilePath $CerPath | Out-Null
    Write-Host "  Exported:   $CerPath" -ForegroundColor Green

    # Remove from personal store — we only needed it there for export.
    # The .pfx file is used by the msix plugin for signing.
    Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
    Write-Host "  Removed from CurrentUser\My (not needed after export)." -ForegroundColor DarkGray
}

# Import .cer into LocalMachine\Root (trust the cert for MSIX install)
$existingTrust = Find-TrustedCert
if ($existingTrust) {
    Write-Host ""
    Write-Host "Certificate '$CertSubject' is already trusted." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Trusting certificate..." -ForegroundColor Cyan
    Import-Certificate -FilePath $CerPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    Write-Host "Certificate added to Trusted Roots." -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "  Test certificate ready!" -ForegroundColor Green
Write-Host ""
Write-Host "  PFX (signing):    $PfxPath" -ForegroundColor White
Write-Host "  CER (trusting):   $CerPath" -ForegroundColor White
Write-Host "  Password:         $CertPassword" -ForegroundColor White
Write-Host "  Subject:          $CertSubject" -ForegroundColor White
Write-Host ""
Write-Host "  Next step: Build the MSIX" -ForegroundColor Yellow
Write-Host "    .\windows\msix\Build-MSIX.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  To untrust later:" -ForegroundColor Yellow
Write-Host "    .\windows\msix\Setup-TestCert.ps1 -Untrust" -ForegroundColor Cyan
Write-Host ""
Write-Host "  To fully remove (untrust + delete files):" -ForegroundColor Yellow
Write-Host "    .\windows\msix\Setup-TestCert.ps1 -Remove" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Green
