import 'package:flutter/foundation.dart';

@immutable
final class AppLogMetadata {
  final String id;
  final DateTime createdAt;
  final int lengthInBytes;

  const AppLogMetadata({
    required this.id,
    required this.createdAt,
    required this.lengthInBytes,
  });

  factory AppLogMetadata.fromJson(Map<String, Object?> json) => AppLogMetadata(
    id: json['id']! as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']! as int),
    lengthInBytes: json['lengthInBytes']! as int,
  );

  AppLogMetadata copyWith({
    int? lengthInBytes,
  }) => AppLogMetadata(
    id: id,
    createdAt: createdAt,
    lengthInBytes: lengthInBytes ?? this.lengthInBytes,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'lengthInBytes': lengthInBytes,
  };

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    lengthInBytes,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLogMetadata && other.id == id && other.createdAt == createdAt && other.lengthInBytes == lengthInBytes;
}
