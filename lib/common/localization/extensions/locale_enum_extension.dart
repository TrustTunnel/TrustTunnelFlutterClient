import 'package:flutter/material.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/tls_authentication_type.dart';
import 'package:trusttunnel/data/model/tls_fingerprint.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';

extension LocaleRoutingModeEnumExtension on RoutingMode {
  String localized(BuildContext context) => switch (this) {
    RoutingMode.bypass => context.ln.bypass,
    RoutingMode.vpn => context.ln.vpn,
  };
}

extension LocaleVpnProtocolEnumExtension on VpnProtocol {
  String localized(BuildContext context) => switch (this) {
    VpnProtocol.http2 => context.ln.http2,
    VpnProtocol.quic => context.ln.quic,
  };
}

extension LocaleTlsAuthenticationTypeEnumExtension on TlsAuthenticationType {
  String localized(BuildContext context) => switch (this) {
    TlsAuthenticationType.clientRandom => context.ln.tlsAuthenticationClientRandom,
    TlsAuthenticationType.clientRandomAuthKey => context.ln.tlsAuthenticationClientRandomAuthKey,
  };
}

extension LocaleTlsFingerprintEnumExtension on TlsFingerprint {
  String localized(BuildContext context) => switch (this) {
    TlsFingerprint.chrome => context.ln.tlsFingerprintChrome,
    TlsFingerprint.chromeCanary => context.ln.tlsFingerprintChromeCanary,
    TlsFingerprint.safari => context.ln.tlsFingerprintSafari,
    TlsFingerprint.firefox => context.ln.tlsFingerprintFirefox,
    TlsFingerprint.okhttp => context.ln.tlsFingerprintOkHttp,
    TlsFingerprint.openssl => context.ln.tlsFingerprintOpenSsl,
    TlsFingerprint.own => context.ln.tlsFingerprintOwn,
  };
}
