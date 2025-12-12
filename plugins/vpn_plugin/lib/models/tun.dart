final class Tun {
  final List<String> includedRoutes;
  final List<String> excludedRoutes;
  final int mtuSize;

  Tun({
    this.includedRoutes = const [
      '0.0.0.0/0',
      '2000::/3',
    ],
    this.excludedRoutes = const [],
    this.mtuSize = 1500,
  }) : assert(mtuSize > 0, 'mtuSize must be greater than 0');
}
