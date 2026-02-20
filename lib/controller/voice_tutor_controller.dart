import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services (API call etc)/audio_recorder_service.dart';
import '../services (API call etc)/voice_tutor_service.dart';
import '../services (API call etc)/tts_player_service.dart';

/// States for the voice tutor's turn lifecycle.
enum VoiceTutorState {
  idle,        // ready to record
  recording,   // mic is open
  processing,  // audio sent to backend, waiting for reply
  playing,     // AI audio response is playing
  error,       // something went wrong (see errorMessage)
}

/// ChangeNotifier controller for the voice tutor feature.
/// Wire this into your widget tree via ChangeNotifierProvider or
/// provide it directly as a field on your screen widget.
class VoiceTutorController extends ChangeNotifier {
  final AudioRecorderService _recorder = AudioRecorderService();
  final VoiceTutorService    _api      = VoiceTutorService();
  final TtsPlayerService     _player   = TtsPlayerService();

  // ── State ────────────────────────────────────────────────────────────────
  VoiceTutorState _state = VoiceTutorState.idle;
  VoiceTutorState get state => _state;

  String _transcript   = '';
  String _replyText    = '';
  String _errorMessage = '';

  String get transcript   => _transcript;
  String get replyText    => _replyText;
  String get errorMessage => _errorMessage;

  bool get isRecording   => _state == VoiceTutorState.recording;
  bool get isProcessing  => _state == VoiceTutorState.processing;
  bool get isPlaying     => _state == VoiceTutorState.playing;
  bool get isIdle        => _state == VoiceTutorState.idle;
  bool get hasError      => _state == VoiceTutorState.error;

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
    } else if (_state == VoiceTutorState.idle || _state == VoiceTutorState.error) {
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
    _transcript  = '';
    _replyText   = '';
    _errorMessage= '';
    _setState(VoiceTutorState.idle);
  }

  // ── Private Logic ─────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    _errorMessage = '';

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _setError('Microphone permission denied. Please grant it in device settings.');
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
        history:   _history,
        examContext: examContext,
      );

      _transcript = result.transcript;
      _replyText  = result.replyText;

      // Add this turn to history
      if (result.transcript.isNotEmpty && result.replyText.isNotEmpty) {
        _history.add(ChatTurn(
          user:      result.transcript,
          assistant: result.replyText,
        ));
        // Keep only the last maxHistory turns
        if (_history.length > maxHistory) {
          _history.removeRange(0, _history.length - maxHistory);
        }
      }

      notifyListeners();

      // Play audio response
      if (result.audioBase64.isNotEmpty) {
        _setState(VoiceTutorState.playing);
        await _player.playBase64Mp3(result.audioBase64);
      }

      _setState(VoiceTutorState.idle);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      debugPrint('[VoiceTutorController] Error: $msg');
      _setError(_friendlyError(msg));
    } finally {
      // Clean up audio file
      try { audioFile?.deleteSync(); } catch (_) {}
    }
  }

  void _setState(VoiceTutorState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = VoiceTutorState.error;
    notifyListeners();
  }

  String _friendlyError(String raw) {
    if (raw.contains('SocketException') || raw.contains('Connection refused')) {
      return 'Cannot reach the tutor server. Make sure it is running and the URL in .env is correct.';
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

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
    super.dispose();
  }
}