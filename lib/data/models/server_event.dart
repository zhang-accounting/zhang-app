import 'dart:convert';

import 'json_utils.dart';

/// A `data:` payload of the `GET /api/sse` event stream.
///
/// On [ServerReload] refetch everything that is displayed (ids change). On
/// [ServerReloadFailed] the server keeps serving the version it loaded
/// before (zhang ≥ 0.2).
sealed class ServerEvent {
  const ServerEvent();

  factory ServerEvent.fromJson(Object? json) {
    final m = asMap(json, 'sse event');
    final type = reqString(m, 'type');
    return switch (type) {
      'Connected' => const ServerConnected(),
      'Reload' => const ServerReload(),
      'ReloadFailed' => ServerReloadFailed(file: optString(m, 'file'), message: optString(m, 'message') ?? ''),
      'NewVersionFound' => ServerNewVersionFound(optString(m, 'version') ?? ''),
      _ => ServerUnknownEvent(type),
    };
  }

  /// Parses one SSE `data:` line payload (the JSON text after `data: `).
  factory ServerEvent.parse(String data) => ServerEvent.fromJson(jsonDecode(data));
}

final class ServerConnected extends ServerEvent {
  const ServerConnected();
}

/// The ledger reloaded successfully (after a write or a file change).
final class ServerReload extends ServerEvent {
  const ServerReload();
}

/// The ledger failed to reload (a file does not parse, …).
final class ServerReloadFailed extends ServerEvent {
  const ServerReloadFailed({this.file, required this.message});

  final String? file;
  final String message;
}

final class ServerNewVersionFound extends ServerEvent {
  const ServerNewVersionFound(this.version);

  final String version;
}

final class ServerUnknownEvent extends ServerEvent {
  const ServerUnknownEvent(this.type);

  final String type;
}
