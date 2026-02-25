import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final FlutterTts _flutterTts = FlutterTts();

  bool _disposed = false;
  bool _flutterTtsReady = false;
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


  /// Initialises FlutterTts engine (call once during setup).
  Future<void> _initFlutterTts() async {
    if (_flutterTtsReady) return;
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      // Do NOT use awaitSpeakCompletion(true) — its internal Future never resolves
      _flutterTtsReady = true;
      debugPrint('[VoiceTutor] FlutterTts initialised');
    } catch (e) {
      debugPrint('[VoiceTutor] FlutterTts init error: $e');
    }
  }

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
    await _flutterTts.stop();
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

  /// Requests mic permission, then starts listening via on-device STT.
  Future<void> _startListening() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _setError(
        'Microphone permission is required for the voice tutor.\n'
        'Please enable it in your device Settings → Apps → Permissions.',
      );
      return;
    }

    _initFlutterTts();
    _errorMessage = '';
    _liveWords = '';
    _transcript = '';
    _processingStarted = false; // reset guard for new session

    bool wasUninitialized = !_speechAvailable;

    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('[VoiceTutor] Speech error: ${error.errorMsg}');
          // Treat these Android errors as non-fatal: session ended, process whatever we captured.
          // error_client  = Android recognizer disconnected (very common on emulator)
          // error_no_match = no recognition match
          // error_speech_timeout = silence timeout
          const nonFatalErrors = {
            'error_speech_timeout',
            'error_no_match',
            'error_client',
          };
          if (nonFatalErrors.contains(error.errorMsg)) {
            if (_state == VoiceTutorState.listening && !_processingStarted) {
              _processingStarted = true;
              // Small delay so any in-flight onResult callbacks can arrive first
              Future.delayed(const Duration(milliseconds: 500), _processTranscript);
            }
          } else {
            _setError('Speech recognition error: ${error.errorMsg}');
          }
        },
        onStatus: (status) {
          debugPrint('[VoiceTutor] Speech status: $status');
          if (status == 'done' && _state == VoiceTutorState.listening && !_processingStarted) {
            _processingStarted = true;
            // Wait 500ms so that any pending onResult with recognizedWords can update
            // _transcript / _liveWords before we process them.
            Future.delayed(const Duration(milliseconds: 500), _processTranscript);
          }
        },
      );

      if (!_speechAvailable) {
        _setError(
            'Speech recognition is not available on this device. Please check microphone permissions.');
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
        // Capture every partial result so we always have the latest words
        if (result.recognizedWords.isNotEmpty) {
          _liveWords = result.recognizedWords;
          _safeNotify();
        }
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _transcript = result.recognizedWords;
          debugPrint('[VoiceTutor] Final result: "$_transcript"');
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en-US',
      listenOptions: stt.SpeechListenOptions(
        // deviceDefault is more reliable than dictation on Android emulator
        listenMode: stt.ListenMode.deviceDefault,
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
      // User didn't say anything — silently return to idle so they can tap again.
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

      // Play audio response – prefer backend MP3, fall back to on-device TTS.
      _setState(VoiceTutorState.playing);
      if (result.audioBase64.isNotEmpty) {
        try {
          await _player.playBase64Mp3(result.audioBase64);
        } catch (e) {
          debugPrint('[VoiceTutor] Backend audio playback failed, using device TTS: $e');
          await _speakWithDeviceTts(_replyText);
        }
      } else {
        // No backend audio – use on-device TTS so user always gets a voice reply.
        debugPrint('[VoiceTutor] No backend audio received – using device TTS fallback.');
        await _speakWithDeviceTts(_replyText);
      }

      if (_state == VoiceTutorState.playing) {
        _setState(VoiceTutorState.idle);
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      debugPrint('[VoiceTutorController] Error: $msg');
      _setError(_friendlyError(msg));
    }
  }

  /// Speaks [text] using the device's built-in TTS engine.
  /// Uses a Completer+timeout so the UI is never stuck in the 'playing' state.
  Future<void> _speakWithDeviceTts(String text) async {
    if (text.isEmpty) return;
    try {
      await _initFlutterTts();
      debugPrint('[VoiceTutor] Device TTS speaking: ${text.substring(0, text.length.clamp(0, 60))}…');

      // Register handlers BEFORE speak() so we never miss the completion event.
      final completer = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        debugPrint('[VoiceTutor] Device TTS handler: complete');
        if (!completer.isCompleted) completer.complete();
      });
      _flutterTts.setErrorHandler((msg) {
        debugPrint('[VoiceTutor] Device TTS handler: error — $msg');
        if (!completer.isCompleted) completer.complete();
      });
      _flutterTts.setCancelHandler(() {
        debugPrint('[VoiceTutor] Device TTS handler: cancelled');
        if (!completer.isCompleted) completer.complete();
      });

      await _flutterTts.speak(text);

      // Wait for completion with a hard 30-second timeout so we NEVER get stuck.
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[VoiceTutor] Device TTS timed out — forcing idle');
        },
      );
      debugPrint('[VoiceTutor] Device TTS complete.');
    } catch (e) {
      debugPrint('[VoiceTutor] Device TTS error: $e');
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
    _flutterTts.stop();
    _player.dispose().catchError((e) {
      debugPrint('[VoiceTutorController] player dispose error: $e');
    });
    super.dispose();
  }
}