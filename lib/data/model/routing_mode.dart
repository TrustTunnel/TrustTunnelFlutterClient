
enum RoutingMode {
  bypass(value: 1),
  vpn(value: 2),
  ;

  final int value;

  const RoutingMode({required this.value});

  @override
  String toString() {
    return switch (this) {
      RoutingMode.bypass => 'BYPASS',
      RoutingMode.vpn => 'VPN',
    };
  }
}
