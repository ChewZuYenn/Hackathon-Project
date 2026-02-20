import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Handles microphone recording using the `record` package.
/// Saves audio as M4A (AAC) which is native on both Android and iOS.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  /// Returns true if the microphone permission has been granted.
  Future<bool> hasPermission() async {
    return _recorder.hasPermission();
  }

  /// Starts recording. Returns false if permission is denied.
  Future<bool> startRecording() async {
    try {
      final permitted = await _recorder.hasPermission();
      if (!permitted) {
        debugPrint('[AudioRecorder] Microphone permission denied.');
        return false;
      }

      final dir = await getTemporaryDirectory();
      _currentPath = '${dir.path}/voice_tutor_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,   // M4A/AAC — great quality, small size
          bitRate: 64000,                 // 64 kbps — sufficient for speech
          sampleRate: 16000,              // 16 kHz — Whisper prefers this
        ),
        path: _currentPath!,
      );

      _isRecording = true;
      debugPrint('[AudioRecorder] Recording started → $_currentPath');
      return true;
    } catch (e) {
      debugPrint('[AudioRecorder] startRecording error: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stops recording and returns the audio file, or null on error.
  Future<File?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null) {
        debugPrint('[AudioRecorder] stopRecording: no path returned');
        return null;
      }

      final file = File(path);
      if (!file.existsSync()) {
        debugPrint('[AudioRecorder] stopRecording: file not found at $path');
        return null;
      }

      final sizeKb = (file.lengthSync() / 1024).toStringAsFixed(1);
      debugPrint('[AudioRecorder] Recording saved: $path  (${sizeKb}KB)');
      return file;
    } catch (e) {
      debugPrint('[AudioRecorder] stopRecording error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancels recording without saving.
  Future<void> cancelRecording() async {
    try {
      await _recorder.cancel();
      _isRecording = false;

      if (_currentPath != null) {
        final f = File(_currentPath!);
        if (f.existsSync()) f.deleteSync();
        _currentPath = null;
      }
    } catch (e) {
      debugPrint('[AudioRecorder] cancelRecording error: $e');
    }
  }

  /// Clean up resources.
  Future<void> dispose() async {
    if (_isRecording) await cancelRecording();
    await _recorder.dispose();
  }
}