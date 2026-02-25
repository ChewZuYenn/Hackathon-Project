import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Plays MP3 audio that arrives as a base64 string from the backend.
/// Uses the `just_audio` package.
class TtsPlayerService {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Stream of playback state changes (connect your UI to this).
  Stream<bool> get playingStream =>
      _player.playerStateStream.map((s) => s.playing);

  /// Decodes [audioBase64], writes to a temp file, and plays it.
  /// Returns when playback is fully complete (or throws on error).
  Future<void> playBase64Mp3(String audioBase64) async {
    if (audioBase64.isEmpty) {
      debugPrint('[TtsPlayer] Empty audio — skipping playback.');
      return;
    }

    File? tempFile;
    StreamSubscription<ProcessingState>? sub;
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

      await _player.setFilePath(tempFile.path);
      _isPlaying = true;

      // stop() call and firstWhere() returns immediately without playing anything.
      final completer = Completer<void>();
      sub = _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed ||
            state == ProcessingState.idle) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      // resolves when the command is dispatched, not when audio finishes.
      _player.play();

      // Wait for the completed/idle state (with a generous timeout).
      await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => debugPrint('[TtsPlayer] Playback timeout — continuing'),
      );

      _isPlaying = false;
      debugPrint('[TtsPlayer] Playback complete.');
    } catch (e) {
      _isPlaying = false;
      debugPrint('[TtsPlayer] Playback error: $e');
      rethrow;
    } finally {
      await sub?.cancel();
      // Small delay before deleting so the OS releases the file handle
      try {
        await Future.delayed(const Duration(milliseconds: 300));
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