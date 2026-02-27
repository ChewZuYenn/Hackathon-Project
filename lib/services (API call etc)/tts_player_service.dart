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
    try {
      // Stop any previous audio cleanly before starting a new one
      if (_player.playing) {
        await _player.stop();
      }

      // Decode and write to disk (just_audio needs a real file URI on Android)
      final bytes = base64Decode(audioBase64);
      final dir = await getTemporaryDirectory();
      tempFile = File(
          '${dir.path}/tts_reply_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await tempFile.writeAsBytes(bytes, flush: true);

      debugPrint(
          '[TtsPlayer] Loaded ${(bytes.length / 1024).toStringAsFixed(1)}KB MP3');

      // Load the file into just_audio
      await _player.setFilePath(tempFile.path);
      _isPlaying = true;

      // In just_audio 0.9.x, play() returns a Future that completes when the
      // player transitions from playing to not-playing (end of track or stop()).
      // This is the correct, race-condition-free way to await actual completion.
      await _player.play();

      _isPlaying = false;
      debugPrint('[TtsPlayer] Playback complete.');
    } catch (e) {
      _isPlaying = false;
      debugPrint('[TtsPlayer] Playback error: $e');
      rethrow;
    } finally {
      // Delete temp file AFTER we know playback is done (or on error)
      try {
        await Future.delayed(const Duration(milliseconds: 500));
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