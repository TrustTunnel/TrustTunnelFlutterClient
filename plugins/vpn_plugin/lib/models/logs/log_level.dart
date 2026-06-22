sealed class LogLevel {
  final String name;

  const LogLevel({required this.name});

  factory LogLevel.fromString(String s) {
    switch (s.toLowerCase()) {
      case '[info]':
        return const _LogLevelInfo();
      case '[debug]':
        return const _LogLevelDebug();
      case '[error]':
        return const _LogLevelError();
      case '[warn]':
        return const _LogLevelWarn();
      default:
        return _LogLevelCustom(s);
    }
  }
}

final class _LogLevelInfo extends LogLevel {
  const _LogLevelInfo() : super(name: 'info');
}

final class _LogLevelDebug extends LogLevel {
  const _LogLevelDebug() : super(name: 'debug');
}

final class _LogLevelError extends LogLevel {
  const _LogLevelError() : super(name: 'error');
}

final class _LogLevelWarn extends LogLevel {
  const _LogLevelWarn() : super(name: 'warn');
}

final class _LogLevelCustom extends LogLevel {
  const _LogLevelCustom(String name) : super(name: name);
}
