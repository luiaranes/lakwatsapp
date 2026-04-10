import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:liquid_speech/liquid_speech.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

enum SpeechProvider { liquidSpeech, speechToText, none }

enum SpeechStatus { idle, listening, processing, error }

class SpeechEvent {
  final SpeechStatus status;
  final String? transcript;
  final bool isFinal;
  final String? error;
  final DateTime timestamp;

  SpeechEvent({
    required this.status,
    this.transcript,
    this.isFinal = false,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SpeechEvent.idle() => SpeechEvent(status: SpeechStatus.idle);

  factory SpeechEvent.listening({String? transcript}) => SpeechEvent(
        status: SpeechStatus.listening,
        transcript: transcript,
      );

  factory SpeechEvent.update(String transcript, {bool isFinal = false}) =>
      SpeechEvent(
        status: SpeechStatus.listening,
        transcript: transcript,
        isFinal: isFinal,
      );

  factory SpeechEvent.stopped(String? finalTranscript) => SpeechEvent(
        status: SpeechStatus.idle,
        transcript: finalTranscript,
        isFinal: true,
      );

  factory SpeechEvent.error(String message) => SpeechEvent(
        status: SpeechStatus.error,
        error: message,
      );
}

class SpeechService {
  static SpeechService? _instance;
  static SpeechService get instance => _instance ??= SpeechService._();

  SpeechService._();

  SpeechAnalyzerService? _liquidSpeech;
  stt.SpeechToText? _speechToText;

  SpeechProvider _provider = SpeechProvider.none;
  bool _isInitialized = false;
  bool _isListening = false;

  final _eventController = StreamController<SpeechEvent>.broadcast();
  Stream<SpeechEvent> get events => _eventController.stream;

  String _currentTranscript = '';
  String get currentTranscript => _currentTranscript;

  bool get isListening => _isListening;
  bool get isAvailable => _provider != SpeechProvider.none;
  SpeechProvider get provider => _provider;

  StreamSubscription? _liquidSpeechSubscription;

  Future<bool> initialize() async {
    if (_isInitialized) return isAvailable;

    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        final available = await _tryInitLiquidSpeech();
        if (available) {
          _provider = SpeechProvider.liquidSpeech;
          _isInitialized = true;
          debugPrint('SpeechService: Using LiquidSpeech (iOS 26+ SpeechAnalyzer)');
          return true;
        }
      }

      final available = await _tryInitSpeechToText();
      if (available) {
        _provider = SpeechProvider.speechToText;
        _isInitialized = true;
        debugPrint('SpeechService: Using SpeechToText fallback');
        return true;
      }

      _provider = SpeechProvider.none;
      _isInitialized = true;
      debugPrint('SpeechService: No speech recognition available');
      return false;
    } catch (e) {
      debugPrint('SpeechService initialization error: $e');
      _provider = SpeechProvider.none;
      _isInitialized = true;
      return false;
    }
  }

  Future<bool> _tryInitLiquidSpeech() async {
    try {
      _liquidSpeech = SpeechAnalyzerService();
      final available = await _liquidSpeech!.isAvailable();
      if (!available) {
        _liquidSpeech = null;
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('LiquidSpeech init failed: $e');
      _liquidSpeech = null;
      return false;
    }
  }

  Future<bool> _tryInitSpeechToText() async {
    try {
      _speechToText = stt.SpeechToText();
      final available = await _speechToText!.initialize(
        onError: (error) {
          debugPrint('SpeechToText error: ${error.errorMsg}');
          _eventController.add(SpeechEvent.error(error.errorMsg));
        },
        onStatus: (status) {
          debugPrint('SpeechToText status: $status');
        },
      );
      if (!available) {
        _speechToText = null;
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('SpeechToText init failed: $e');
      _speechToText = null;
      return false;
    }
  }

  Future<bool> startListening() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!isAvailable) {
      _eventController.add(SpeechEvent.error('Speech recognition not available'));
      return false;
    }

    if (_isListening) {
      return true;
    }

    _currentTranscript = '';

    switch (_provider) {
      case SpeechProvider.liquidSpeech:
        return _startLiquidSpeech();
      case SpeechProvider.speechToText:
        return _startSpeechToText();
      case SpeechProvider.none:
        return false;
    }
  }

  Future<bool> _startLiquidSpeech() async {
    try {
      _liquidSpeechSubscription?.cancel();
      _liquidSpeechSubscription = _liquidSpeech!.transcriptionEvents.listen(
        (event) {
          switch (event.type) {
            case 'started':
              _isListening = true;
              _eventController.add(SpeechEvent.listening());
              break;
            case 'update':
              if (event.transcript != null) {
                _currentTranscript = event.transcript!;
                _eventController.add(SpeechEvent.update(
                  event.transcript!,
                  isFinal: event.isFinal,
                ));
              }
              break;
            case 'stopped':
              _isListening = false;
              _eventController.add(SpeechEvent.stopped(event.transcript));
              break;
            case 'error':
              _isListening = false;
              final errorMsg = _getUserFriendlyError(event.error);
              _eventController.add(SpeechEvent.error(errorMsg));
              break;
          }
        },
      );

      final success = await _liquidSpeech!.startTranscription();
      if (success) {
        _isListening = true;
        _eventController.add(SpeechEvent.listening());
      } else {
        _eventController.add(SpeechEvent.error(
          'Voice input requires a real device. Simulators do not support microphone access.',
        ));
      }
      return success;
    } catch (e) {
      debugPrint('LiquidSpeech start error: $e');
      _liquidSpeechSubscription?.cancel();
      _liquidSpeechSubscription = null;
      final errorMsg = _getUserFriendlyError(e.toString());
      _eventController.add(SpeechEvent.error(errorMsg));
      return false;
    }
  }

  String _getUserFriendlyError(String? error) {
    if (error == null) return 'Voice input failed';
    
    final lowerError = error.toLowerCase();
    
    if (lowerError.contains('audio format') || 
        lowerError.contains('transcriber') ||
        lowerError.contains('microphone')) {
      return 'Voice input requires a real device. Simulators do not support microphone access.';
    }
    
    if (lowerError.contains('permission') || lowerError.contains('denied')) {
      return 'Microphone permission denied. Please enable it in Settings.';
    }
    
    if (lowerError.contains('network') || lowerError.contains('internet')) {
      return 'Voice input requires an internet connection.';
    }
    
    return error;
  }

  Future<bool> _startSpeechToText() async {
    try {
      _isListening = true;
      _eventController.add(SpeechEvent.listening());

      await _speechToText!.listen(
        onResult: (SpeechRecognitionResult result) {
          _currentTranscript = result.recognizedWords;
          _eventController.add(SpeechEvent.update(
            result.recognizedWords,
            isFinal: result.finalResult,
          ));

          if (result.finalResult) {
            _isListening = false;
            _eventController.add(SpeechEvent.stopped(result.recognizedWords));
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );

      return true;
    } catch (e) {
      _isListening = false;
      debugPrint('SpeechToText start error: $e');
      _eventController.add(SpeechEvent.error(e.toString()));
      return false;
    }
  }

  Future<String?> stopListening() async {
    if (!_isListening) {
      return _currentTranscript.isNotEmpty ? _currentTranscript : null;
    }

    switch (_provider) {
      case SpeechProvider.liquidSpeech:
        return _stopLiquidSpeech();
      case SpeechProvider.speechToText:
        return _stopSpeechToText();
      case SpeechProvider.none:
        return null;
    }
  }

  Future<String?> _stopLiquidSpeech() async {
    try {
      _liquidSpeechSubscription?.cancel();
      _liquidSpeechSubscription = null;
      final transcript = await _liquidSpeech!.stopTranscription();
      _isListening = false;
      _eventController.add(SpeechEvent.stopped(transcript));
      return transcript ?? _currentTranscript;
    } catch (e) {
      _isListening = false;
      debugPrint('LiquidSpeech stop error: $e');
      return _currentTranscript.isNotEmpty ? _currentTranscript : null;
    }
  }

  Future<String?> _stopSpeechToText() async {
    try {
      await _speechToText!.stop();
      _isListening = false;
      _eventController.add(SpeechEvent.stopped(_currentTranscript));
      return _currentTranscript.isNotEmpty ? _currentTranscript : null;
    } catch (e) {
      _isListening = false;
      debugPrint('SpeechToText stop error: $e');
      return _currentTranscript.isNotEmpty ? _currentTranscript : null;
    }
  }

  void cancel() {
    _isListening = false;
    _currentTranscript = '';

    switch (_provider) {
      case SpeechProvider.liquidSpeech:
        _liquidSpeechSubscription?.cancel();
        _liquidSpeechSubscription = null;
        _liquidSpeech?.stopTranscription();
        break;
      case SpeechProvider.speechToText:
        _speechToText?.cancel();
        break;
      case SpeechProvider.none:
        break;
    }

    _eventController.add(SpeechEvent.idle());
  }

  void dispose() {
    _liquidSpeechSubscription?.cancel();
    _liquidSpeech?.dispose();
    _speechToText?.cancel();
    _eventController.close();
    _instance = null;
  }
}
