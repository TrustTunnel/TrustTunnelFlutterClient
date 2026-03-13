import 'package:meta/meta.dart';

@immutable
class ValueData<T> {
  final T? value;

  const ValueData(
    this.value,
  );

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();

  @override
  bool operator ==(covariant ValueData<T> other) {
    if (identical(this, other)) return true;

    return other.value == value;
  }
}
