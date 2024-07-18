enum VpnProtocol {
  http2(value: 1),
  quic(value: 2),
  ;

  final int value;

  const VpnProtocol({required this.value});

  @override
  String toString() {
    return switch (this) {
      VpnProtocol.http2 => 'HTTP/2',
      VpnProtocol.quic => 'QUIC',
    };
  }
}
