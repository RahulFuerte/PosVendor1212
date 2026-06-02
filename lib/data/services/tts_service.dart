import 'package:flutter_tts/flutter_tts.dart';

/// Online TTS service - speaks bill amounts after payment
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> _init() async {
    if (_isInitialized) return;
    await _flutterTts.setLanguage('en-IN');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _isInitialized = true;
  }

  /// Speak the given text aloud
  static Future<void> speak(String text) async {
    try {
      final svc = TtsService();
      await svc._init();
      await svc._flutterTts.speak(text);
    } catch (e) {
      // TTS is non-critical — silently ignore errors
    }
  }

  Future<void> dispose() async {
    await _flutterTts.stop();
    _isInitialized = false;
  }
}
