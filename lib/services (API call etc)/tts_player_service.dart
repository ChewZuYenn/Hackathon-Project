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
  /// Returns when playback is complete (or throws on error).
  Future<void> playBase64Mp3(String audioBase64) async {
    if (audioBase64.isEmpty) {
      debugPrint('[TtsPlayer] Empty audio — skipping playback.');
      return;
    }

    try {
      // Stop any current playback
      await _player.stop();

      // Decode and write to disk (just_audio needs a file URI on Android)
      final bytes = base64Decode(audioBase64);
      final dir   = await getTemporaryDirectory();
      final file  = File('${dir.path}/tts_reply_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);

      debugPrint('[TtsPlayer] Playing ${(bytes.length / 1024).toStringAsFixed(1)}KB MP3');

      await _player.setFilePath(file.path);
      _isPlaying = true;
      await _player.play();

      // Wait until playback finishes
      await _player.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed || !s.playing,
      );
      _isPlaying = false;

      // Clean up temp file
      try { file.deleteSync(); } catch (_) {}
    } catch (e) {
      _isPlaying = false;
      debugPrint('[TtsPlayer] Playback error: $e');
      rethrow;
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