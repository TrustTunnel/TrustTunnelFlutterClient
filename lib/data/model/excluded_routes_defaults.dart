/// Factory-default routes excluded from VPN/TUN routing.
const List<String> defaultExcludedRoutes = [
  '10.0.0.0/8',
  '100.64.0.0/10',
  '169.254.0.0/16',
  '172.16.0.0/12',
  '192.0.0.0/24',
  '192.168.0.0/16',
  '255.255.255.255/32',
];
