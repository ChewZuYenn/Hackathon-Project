import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services (API call etc)/audio_recorder_service.dart';
import '../services (API call etc)/voice_tutor_service.dart';
import '../services (API call etc)/tts_player_service.dart';

/// States for the voice tutor's turn lifecycle.
enum VoiceTutorState {
  idle,       // ready to record
  recording,  // mic is open
  processing, // audio sent to backend, waiting for reply
  playing,    // AI audio response is playing
  error,      // something went wrong (see errorMessage)
}

/// ChangeNotifier controller for the voice tutor feature.
class VoiceTutorController extends ChangeNotifier {
  final AudioRecorderService _recorder = AudioRecorderService();
  final VoiceTutorService _api = VoiceTutorService();
  final TtsPlayerService _player = TtsPlayerService();

  // FIX: Track whether the controller has been disposed to avoid
  // calling notifyListeners() after disposal (causes crashes).
  bool _disposed = false;

  // ── State ─────────────────────────────────────────────────────────────────
  VoiceTutorState _state = VoiceTutorState.idle;
  VoiceTutorState get state => _state;

  String _transcript = '';
  String _replyText = '';
  String _errorMessage = '';

  String get transcript => _transcript;
  String get replyText => _replyText;
  String get errorMessage => _errorMessage;

  bool get isRecording => _state == VoiceTutorState.recording;
  bool get isProcessing => _state == VoiceTutorState.processing;
  bool get isPlaying => _state == VoiceTutorState.playing;
  bool get isIdle => _state == VoiceTutorState.idle;
  bool get hasError => _state == VoiceTutorState.error;

  /// Conversation history – last [maxHistory] turns.
  final List<ChatTurn> _history = [];
  List<ChatTurn> get history => List.unmodifiable(_history);
  static const int maxHistory = 10;

  /// Exam context – set this from the QuestionScreen before opening the tutor.
  Map<String, String> examContext = {};

  // ── Public Actions ────────────────────────────────────────────────────────

  /// Toggles mic: starts recording if idle, stops if recording.
  Future<void> toggleRecording() async {
    if (_state == VoiceTutorState.recording) {
      await _stopAndProcess();
    } else if (_state == VoiceTutorState.idle ||
        _state == VoiceTutorState.error) {
      await _startRecording();
    }
    // Ignore taps while processing/playing
  }

  /// Stops playback immediately.
  Future<void> stopPlayback() async {
    await _player.stop();
    _setState(VoiceTutorState.idle);
  }

  /// Clears conversation history.
  void clearHistory() {
    _history.clear();
    _transcript = '';
    _replyText = '';
    _errorMessage = '';
    _setState(VoiceTutorState.idle);
  }

  // ── Private Logic ─────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    _errorMessage = '';

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _setError(
          'Microphone permission denied. Please grant it in device settings.');
      return;
    }

    final started = await _recorder.startRecording();
    if (!started) {
      _setError('Could not start the microphone. Please try again.');
      return;
    }

    _setState(VoiceTutorState.recording);
  }

  Future<void> _stopAndProcess() async {
    _setState(VoiceTutorState.processing);

    File? audioFile;
    try {
      audioFile = await _recorder.stopRecording();

      if (audioFile == null) {
        _setError('Recording failed — no audio captured. Please try again.');
        return;
      }

      // Send to backend
      final result = await _api.sendVoiceTurn(
        audioFile: audioFile,
        history: _history,
        examContext: examContext,
      );

      _transcript = result.transcript;
      _replyText = result.replyText;

      // Add this turn to history
      if (result.transcript.isNotEmpty && result.replyText.isNotEmpty) {
        _history.add(ChatTurn(
          user: result.transcript,
          assistant: result.replyText,
        ));
        // Keep only the last maxHistory turns
        if (_history.length > maxHistory) {
          _history.removeRange(0, _history.length - maxHistory);
        }
      }

      _safeNotify();

      // Play audio response
      if (result.audioBase64.isNotEmpty) {
        _setState(VoiceTutorState.playing);
        await _player.playBase64Mp3(result.audioBase64);
      }

      // Only transition to idle if we're still in playing state
      // (user may have tapped stop during playback)
      if (_state == VoiceTutorState.playing) {
        _setState(VoiceTutorState.idle);
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      debugPrint('[VoiceTutorController] Error: $msg');
      _setError(_friendlyError(msg));
    } finally {
      // Clean up audio file
      try {
        audioFile?.deleteSync();
      } catch (_) {}
    }
  }

  void _setState(VoiceTutorState newState) {
    _state = newState;
    _safeNotify();
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = VoiceTutorState.error;
    _safeNotify();
  }

  // FIX: Guard notifyListeners() calls so they're never called after dispose().
  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('SocketException') ||
        raw.contains('Connection refused') ||
        raw.contains('Network is unreachable') ||
        raw.contains('Failed host lookup')) {
      return 'Cannot reach the tutor server. Make sure:\n'
          '• The backend is running (node server.js)\n'
          '• VOICE_TUTOR_BACKEND_URL in .env is correct\n'
          '• Real device: use your computer\'s local IP (e.g. http://192.168.x.x:3000)\n'
          '• Emulator: use http://10.0.2.2:3000';
    }
    if (raw.contains('TimeoutException')) {
      return 'The server took too long to respond. Check your connection and try again.';
    }
    if (raw.contains('STT') || raw.contains('transcript')) {
      return 'Speech recognition failed. Please speak clearly and try again.';
    }
    if (raw.contains('TTS') || raw.contains('ElevenLabs')) {
      return 'Audio generation failed. The reply was: "$_replyText"';
    }
    return 'Something went wrong: $raw';
  }

  // FIX: dispose() must be synchronous for ChangeNotifier.
  // We set _disposed = true first, then fire-and-forget the async cleanup.
  @override
  void dispose() {
    _disposed = true;
    // Fire-and-forget async cleanup — we can't await in dispose()
    _recorder.dispose().catchError((e) {
      debugPrint('[VoiceTutorController] recorder dispose error: $e');
    });
    _player.dispose().catchError((e) {
      debugPrint('[VoiceTutorController] player dispose error: $e');
    });
    super.dispose();
  }
}