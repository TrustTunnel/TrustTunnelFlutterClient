enum LoggingLevel {
  defaultLevel('default'),
  debug('debug')
  ;

  final String value;

  const LoggingLevel(this.value);

  static LoggingLevel parse(String? value) => LoggingLevel.values.firstWhere(
    (level) => level.value == value,
    orElse: () => LoggingLevel.defaultLevel,
  );
}
