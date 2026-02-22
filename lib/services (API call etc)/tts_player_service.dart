import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Plays MP3 audio that arrives as a base64 string from the backend.
/// Uses the `just_audio` package.
class TtsPlayerService {
  AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Stream of playback state changes (connect your UI to this).
  Stream<bool> get playingStream =>
      _player.playerStateStream.map((s) => s.playing);

  /// Decodes [audioBase64], writes to a temp file, and plays it.
  /// Returns when playback is complete (or throws on error).
  Future<void> playBase64Mp3(String audioBase64) async {
    if (audioBase64.isEmpty) {
      debugPrint('[TtsPlayer] Empty audio — skipping playback.');
      return;
    }

    File? tempFile;
    try {
      // Stop any current playback cleanly
      await _player.stop();

      // Decode and write to disk (just_audio needs a file URI on Android)
      final bytes = base64Decode(audioBase64);
      final dir = await getTemporaryDirectory();
      tempFile = File(
          '${dir.path}/tts_reply_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(bytes);

      debugPrint(
          '[TtsPlayer] Playing ${(bytes.length / 1024).toStringAsFixed(1)}KB MP3');

      // missing the completed event if audio is very short.
      final completionFuture = _player.playerStateStream.firstWhere(
        (s) =>
            s.processingState == ProcessingState.completed ||
            s.processingState == ProcessingState.idle,
      );

      await _player.setFilePath(tempFile.path);
      _isPlaying = true;
      _player.play(); // intentionally not awaited ,just_audio's play() resolves when done

      // Wait for completion signal from the stream
      await completionFuture.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('[TtsPlayer] Playback timed out — forcing stop');
          _player.stop();
          return _player.playerStateStream.first;
        },
      );

      _isPlaying = false;
    } catch (e) {
      _isPlaying = false;
      debugPrint('[TtsPlayer] Playback error: $e');
      rethrow;
    } finally {
      // Clean up temp file regardless of success/failure
      try {
        tempFile?.deleteSync();
      } catch (_) {}
    }
  }

  /// Stop currently playing audio.
  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  /// Release resources.
  Future<void> dispose() async {
    await _player.dispose();
  }
}