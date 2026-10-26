/// Hold-to-record over the `record` package (AAC in an .m4a file).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract interface class VoiceRecorder {
  /// False when the microphone is refused.
  Future<bool> start();

  /// Stops and returns the bytes, or null when nothing was recorded.
  Future<Uint8List?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();

  Future<void> dispose();
}

class PluginVoiceRecorder implements VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();
  String? _path;

  @override
  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 48000,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: _path!,
    );
    return true;
  }

  @override
  Future<Uint8List?> stop() async {
    final path = await _rec.stop() ?? _path;
    _path = null;
    if (path == null) return null;
    final file = File(path);
    try {
      return await file.readAsBytes();
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> cancel() async {
    final path = _path;
    _path = null;
    await _rec.cancel();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() => _rec.dispose();
}
