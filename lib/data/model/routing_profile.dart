import 'package:trusttunnel/data/model/routing_profile_data.dart';

class RoutingProfile {
  final String id;
  final RoutingProfileData data;

  RoutingProfile({
    required this.id,
    required this.data,
  });

  @override
  int get hashCode => Object.hashAll(
    [
      id.hashCode,
      data.hashCode,
    ],
  );

  @override
  String toString() => 'RoutingProfile(id: $id, data: $data)';

  @override
  bool operator ==(covariant RoutingProfile other) {
    if (identical(this, other)) return true;

    return other.id == id && other.data == data;
  }

  RoutingProfile copyWith({
    String? id,
    RoutingProfileData? data,
  }) => RoutingProfile(
    id: id ?? this.id,
    data: data ?? this.data,
  );
}
