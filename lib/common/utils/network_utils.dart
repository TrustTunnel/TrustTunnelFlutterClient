import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

abstract final class NetworkUtils {
  /// Uses one timeout for the whole body and cancels the source before returning.
  static Future<Uint8List> readResponseBytes(Stream<List<int>> response, Duration timeout) async {
    final StreamIterator<List<int>> chunks = StreamIterator<List<int>>(response);

    Future<Uint8List> read() async {
      final BytesBuilder bytes = BytesBuilder(copy: false);

      while (true) {
        final bool hasNext = await chunks.moveNext();

        if (!hasNext) {
          return bytes.takeBytes();
        }

        bytes.add(chunks.current);
      }
    }

    try {
      return await read().timeout(timeout);
    } finally {
      await chunks.cancel();
    }
  }

  static Future<void> discardResponse(HttpClientResponse response) => response.listen(null).cancel();
}
