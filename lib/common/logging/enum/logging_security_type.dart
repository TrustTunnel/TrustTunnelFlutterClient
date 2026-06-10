enum LoggingSecurityType {
  stripped('stripped'),
  full('full')
  ;

  final String value;

  const LoggingSecurityType(this.value);

  static LoggingSecurityType parse(String? value) => LoggingSecurityType.values.firstWhere(
    (type) => type.value == value,
    orElse: () => LoggingSecurityType.stripped,
  );
}
