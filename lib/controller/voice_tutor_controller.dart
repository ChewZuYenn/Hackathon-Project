import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services (API call etc)/voice_tutor_service.dart';
import '../services (API call etc)/tts_player_service.dart';
import '../services (API call etc)/conversation_storage_service.dart';

enum VoiceTutorState {
  idle,       // ready to record
  listening,  // mic is open, on-device STT active
  processing, // transcript sent to backend, waiting for AI reply
  playing,    // AI audio response is playing
  error,      // something went wrong (see errorMessage)
}

class VoiceTutorController extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final VoiceTutorService _api = VoiceTutorService();
  final TtsPlayerService _player = TtsPlayerService();

  bool _disposed = false;
  bool _speechAvailable = false;
  bool _processingStarted = false; // guard against double-process from status+error callbacks

  VoiceTutorState _state = VoiceTutorState.idle;
  VoiceTutorState get state => _state;

  String _transcript = '';
  String _replyText = '';
  String _errorMessage = '';
  String _liveWords = ''; // Words recognized so far during listening

  String get transcript => _transcript;
  String get replyText => _replyText;
  String get errorMessage => _errorMessage;
  String get liveWords => _liveWords;

  bool get isListening => _state == VoiceTutorState.listening;
  bool get isProcessing => _state == VoiceTutorState.processing;
  bool get isPlaying => _state == VoiceTutorState.playing;
  bool get isIdle => _state == VoiceTutorState.idle;
  bool get hasError => _state == VoiceTutorState.error;
  bool get isRecording => _state == VoiceTutorState.listening; 

  /// Conversation history – last [maxHistory] turns.
  final List<ChatTurn> _history = [];
  List<ChatTurn> get history => List.unmodifiable(_history);
  static const int maxHistory = 10;

  /// Exam context – set from question_screen before using the tutor.
  Map<String, String> examContext = {};

  /// The current question text — injected by question_screen.
  String questionText = '';

  /// The student's working space text — injected by question_screen on each turn.
  String workingSpaceText = '';

  /// Session ID for local history storage (e.g. "examType_subject_topic").
  String _sessionId = 'default';


  /// Call after setting [examContext] to load persisted history from storage.
  Future<void> loadHistory() async {
    _sessionId = [
      examContext['examType'] ?? '',
      examContext['subject'] ?? '',
      examContext['topic'] ?? '',
    ].where((s) => s.isNotEmpty).join('_').replaceAll(' ', '-');

    final stored = await ConversationStorageService.load(_sessionId);
    _history.clear();
    for (final t in stored) {
      _history.add(ChatTurn(user: t.user, assistant: t.assistant));
    }
    debugPrint('[VoiceTutor] Loaded ${_history.length} turns from storage (session: $_sessionId)');
    _safeNotify();
  }


  /// Toggles mic: starts listening if idle, stops if listening.
  Future<void> toggleRecording() async {
    if (_state == VoiceTutorState.listening) {
      await _stopListeningAndProcess();
    } else if (_state == VoiceTutorState.idle ||
        _state == VoiceTutorState.error) {
      await _startListening();
    }
    // Ignore taps while processing/playing
  }

  /// Stops playback immediately.
  Future<void> stopPlayback() async {
    await _player.stop();
    _setState(VoiceTutorState.idle);
  }

  /// Clears conversation history (memory + local storage).
  Future<void> clearHistory() async {
    _history.clear();
    _transcript = '';
    _replyText = '';
    _errorMessage = '';
    _liveWords = '';
    await ConversationStorageService.clear(_sessionId);
    _setState(VoiceTutorState.idle);
  }

  /// Sends an audio file to the backend for transcription + AI chat + TTS.
  Future<void> _startListening() async {
    _errorMessage = '';
    _liveWords = '';
    _transcript = '';
    _processingStarted = false; // reset guard for new session

    bool wasUninitialized = !_speechAvailable;

    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('[VoiceTutor] Speech error: ${error.errorMsg}');
          if (error.errorMsg == 'error_speech_timeout' ||
              error.errorMsg == 'error_no_match') {
            // On web/Chrome these fire when the session ends ,process whatever we captured
            if (_state == VoiceTutorState.listening && !_processingStarted) {
              _processingStarted = true;
              _processTranscript();
            }
          } else {
            _setError('Speech recognition error: ${error.errorMsg}');
          }
        },
        onStatus: (status) {
          debugPrint('[VoiceTutor] Speech status: $status');
          if (status == 'done' && _state == VoiceTutorState.listening && !_processingStarted) {
            _processingStarted = true;
            _processTranscript();
          }
        },
      );

      if (!_speechAvailable) {
        _setError(
            'Speech recognition is not available. Please check microphone permissions in device settings.');
        return;
      }
    }

    _setState(VoiceTutorState.listening);

    if (wasUninitialized) {
      // Give the OS speech service a tiny moment to warm up before starting to listen.
      // This prevents the instant "done" / "error_no_match" bug on the very first tap.
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await _speech.listen(
      onResult: (result) {
        _liveWords = result.recognizedWords;
        _safeNotify();
        if (result.finalResult) {
          _transcript = result.recognizedWords;
          debugPrint('[VoiceTutor] Final result: "${_transcript}"');
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  Future<void> _stopListeningAndProcess() async {
    _processingStarted = true; // prevent double-process from callbacks
    await _speech.stop();
    // Use the most complete text available: prefer final result, fall back to partial
    if (_transcript.isEmpty) {
      _transcript = _liveWords;
    }
    await _processTranscript();
  }

  Future<void> _processTranscript() async {
    // Use partial words as fallback if final result hasn't arrived yet
    final text = (_transcript.isNotEmpty ? _transcript : _liveWords).trim();

    if (text.isEmpty) {
      // User didn't say anything
      // Just silently return to idle so they can tap again without an error.
      _setState(VoiceTutorState.idle);
      return;
    }

    _setState(VoiceTutorState.processing);
    debugPrint('[VoiceTutor] Sending: "$text"');
    debugPrint('[VoiceTutor] Working space: "${workingSpaceText.isNotEmpty ? workingSpaceText.substring(0, workingSpaceText.length.clamp(0, 80)) : "(empty)"}…"');

    try {
      final result = await _api.sendChatTurn(
        userText: text,
        history: _history,
        examContext: examContext,
        questionText: questionText,
        workingSpace: workingSpaceText,
      );

      _replyText = result.replyText;
      _transcript = text;

      // Add to in-memory history
      if (text.isNotEmpty && result.replyText.isNotEmpty) {
        _history.add(ChatTurn(user: text, assistant: result.replyText));
        if (_history.length > maxHistory) {
          _history.removeRange(0, _history.length - maxHistory);
        }

        // Persist to local storage
        final storableTurns = _history
            .map((t) => ConversationTurn(
                  user: t.user,
                  assistant: t.assistant,
                  timestamp: DateTime.now(),
                ))
            .toList();
        ConversationStorageService.save(_sessionId, storableTurns);
      }

      _safeNotify();

      // Play audio response if available
      if (result.audioBase64.isNotEmpty) {
        _setState(VoiceTutorState.playing);
        await _player.playBase64Mp3(result.audioBase64);
        if (_state == VoiceTutorState.playing) {
          _setState(VoiceTutorState.idle);
        }
      } else {
        _setState(VoiceTutorState.idle);
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      debugPrint('[VoiceTutorController] Error: $msg');
      _setError(_friendlyError(msg));
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

  void _safeNotify() {
    if (!_disposed) notifyListeners();
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
    if (raw.contains('429') || raw.contains('quota') || raw.contains('RESOURCE_EXHAUSTED')) {
      return 'API rate limit reached. Please wait a minute and try again.';
    }
    if (raw.contains('TTS') || raw.contains('ElevenLabs')) {
      return 'Audio generation failed. The reply was: "$_replyText"';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _disposed = true;
    _speech.stop();
    _player.dispose().catchError((e) {
      debugPrint('[VoiceTutorController] player dispose error: $e');
    });
    super.dispose();
  }
}