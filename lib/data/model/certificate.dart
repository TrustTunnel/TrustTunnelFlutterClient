import 'package:meta/meta.dart';

@immutable
class Certificate {
  final String name;
  final String data;

  const Certificate({
    required this.name,
    required this.data,
  });

  @override
  int get hashCode => Object.hashAll([
    name.hashCode,
    data.hashCode,
  ]);

  @override
  String toString() => 'Certificate(name: $name, data: $data)';

  @override
  bool operator ==(covariant Certificate other) {
    if (identical(this, other)) return true;

    return other.name == name && other.data == data;
  }
}
