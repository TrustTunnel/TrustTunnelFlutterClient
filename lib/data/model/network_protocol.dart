enum NetworkProtocol {
  tcp,
  ;

  @override
  String toString() {
    return switch (this) {
      NetworkProtocol.tcp => 'TCP',
    };
  }
}
