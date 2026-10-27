import 'dart:convert';

import 'package:trusttunnel/data/model/tls_fingerprint.dart';
import 'package:vpn_plugin/models/tls_profile.dart';

class TlsProfileEncoder extends Converter<TlsFingerprint, TlsProfile> {
  const TlsProfileEncoder();

  @override
  TlsProfile convert(TlsFingerprint fingerprint) => switch (fingerprint) {
    TlsFingerprint.chrome => TlsProfile.chrome,
    TlsFingerprint.chromeCanary => TlsProfile.chromeCanary,
    TlsFingerprint.safari => TlsProfile.safari,
    TlsFingerprint.firefox => TlsProfile.firefox,
    TlsFingerprint.okhttp => TlsProfile.okhttp,
    TlsFingerprint.openssl => TlsProfile.openssl,
    TlsFingerprint.own => TlsProfile.defaultProfile,
  };
}

class TlsProfileDecoder extends Converter<TlsProfile, TlsFingerprint> {
  const TlsProfileDecoder();

  @override
  TlsFingerprint convert(TlsProfile profile) => switch (profile) {
    TlsProfile.chrome => TlsFingerprint.chrome,
    TlsProfile.chromeCanary => TlsFingerprint.chromeCanary,
    TlsProfile.safari => TlsFingerprint.safari,
    TlsProfile.firefox => TlsFingerprint.firefox,
    TlsProfile.okhttp => TlsFingerprint.okhttp,
    TlsProfile.openssl => TlsFingerprint.openssl,
    TlsProfile.defaultProfile => TlsFingerprint.own,
  };
}
