// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:trusttunnel/data/model/server_data.dart';

class Server {
  final String id;
  final ServerData serverData;

  Server({
    required this.id,
    required this.serverData,
  });

  @override
  int get hashCode => Object.hashAll([
    id.hashCode,
    serverData.hashCode,
  ]);

  @override
  String toString() => 'Server(id: $id, serverData: $serverData)';

  @override
  bool operator ==(covariant Server other) {
    if (identical(this, other)) return true;

    return other.id == id && other.serverData == serverData;
  }

  Server copyWith({
    String? id,
    ServerData? serverData,
  }) => Server(
    id: id ?? this.id,
    serverData: serverData ?? this.serverData,
  );
}
