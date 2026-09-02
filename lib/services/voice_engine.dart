import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

// Logger ইনস্ট্যান্স ডিফাইন করা হলো যাতে static error না আসে
class Logger {
  static void info(String msg) => debugPrint('[INFO] $msg');
  static void warning(String msg) => debugPrint('[WARN] $msg');
  static void error(String msg, [dynamic stackTrace]) => debugPrint('[ERROR] $msg');
  static void debug(String msg) => debugPrint('[DEBUG] $msg');
}
class VoiceEngine extends ChangeNotifier {
  static final VoiceEngine _instance = VoiceEngine._internal();
  factory VoiceEngine() => _instance;
  VoiceEngine._internal();
  
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  final MethodChannel _nativeChannel = const MethodChannel('com.synapse.ai/native');
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isRecording = false;
  
  String _lastTranscript = '';
  String _currentLanguage = 'en-US';
  double _speechConfidence = 0.0;
  double _volume = 0.0;
  
  final List<Map<String, dynamic>> _voiceHistory = [];
  final Map<String, dynamic> _voiceMetrics = {};
  
  AudioPlayer? _audioPlayer;
  
  // Getters
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isRecording => _isRecording;
  String get lastTranscript => _lastTranscript;
  String get currentLanguage => _currentLanguage;
  double get speechConfidence => _speechConfidence;
  double get volume => _volume;
  
  // Initialization
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Logger.info('Initializing VoiceEngine...');
      
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        Logger.warning('Microphone permission not granted');
      }
      
      // Initialize speech to text
      await _initializeSpeechToText();
      
      // Initialize text to speech
      await _initializeTextToSpeech();
      
      // Initialize audio recorder
      await _initializeAudioRecorder();
      
      // Initialize audio session
      await _initializeAudioSession();
      
      // Initialize audio player
      _audioPlayer = AudioPlayer();
      
      _isInitialized = true;
      Logger.info('VoiceEngine initialized successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('VoiceEngine initialization failed: $e', stackTrace);
      rethrow;
    }
  }
  
  Future<void> _initializeSpeechToText() async {
    try {
      final available = await _speechToText.initialize(
        onDevice: true,
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
      
      if (!available) {
        Logger.warning('Speech to text not available');
      } else {
        // Get available languages
        final languages = await _speechToText.locales();
        Logger.info('Available speech languages: ${languages.length}');
      }
    } catch (e) {
      Logger.error('Speech to text initialization failed: $e');
    }
  }
  
  Future<void> _initializeTextToSpeech() async {
    try {
      await _flutterTts.setLanguage(_currentLanguage);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      
      // Set platform specific settings
      if (Platform.isAndroid) {
        await _flutterTts.setVoice({'name': 'en-us-x-sfg#female_2-local', 'locale': 'en-US'});
      } else if (Platform.isIOS) {
        await _flutterTts.setVoice({'name': 'com.apple.ttsbundle.Samantha-compact', 'locale': 'en-US'});
      }
      
      // Listen for completion events
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      
      _flutterTts.setErrorHandler((msg) {
        Logger.error('TTS Error: $msg');
        _isSpeaking = false;
        notifyListeners();
      });
      
      Logger.info('Text to speech initialized');
    } catch (e) {
      Logger.error('Text to speech initialization failed: $e');
    }
  }
  
  Future<void> _initializeAudioRecorder() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        Logger.warning('Audio recorder permission not granted');
      }
      
      Logger.info('Audio recorder initialized');
    } catch (e) {
      Logger.error('Audio recorder initialization failed: $e');
    }
  }
  
  Future<void> _initializeAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      Logger.info('Audio session initialized');
    } catch (e) {
      Logger.error('Audio session initialization failed: $e');
    }
  }
  
  void _handleSpeechStatus(String status) {
    Logger.debug('Speech status: $status');
    switch (status) {
      case 'listening':
        _isListening = true;
        notifyListeners();
        break;
      case 'notListening':
        _isListening = false;
        notifyListeners();
        break;
      case 'done':
        _isListening = false;
        notifyListeners();
        break;
    }
  }
  
  void _handleSpeechError(dynamic error) {
    Logger.error('Speech error: $error');
    _isListening = false;
    notifyListeners();
  }
  
  // Speech Recognition
  Future<String?> listen({Duration duration = const Duration(seconds: 10)}) async {
    if (_isListening) {
      Logger.warning('Already listening');
      return null;
    }
    
    try {
      Logger.info('Starting speech recognition...');
      
      _isListening = true;
      _speechConfidence = 0.0;
      notifyListeners();
      
      await _speechToText.listen(
        onResult: (result) {
          _lastTranscript = result.recognizedWords;
          _speechConfidence = result.confidence;
          
          // Add to history
          _addToHistory(
            text: _lastTranscript,
            confidence: _speechConfidence,
            type: 'speech_recognition',
          );
          
          notifyListeners();
        },
        listenFor: duration,
        pauseFor: const Duration(seconds: 1),
        onDevice: true,
        localeId: _currentLanguage,
        partialResults: true,
      );
      
      return _lastTranscript;
    } catch (e) {
      _isListening = false;
      Logger.error('Speech recognition failed: $e');
      notifyListeners();
      return null;
    }
  }
  
  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      Logger.info('Listening stopped');
      notifyListeners();
    }
  }
  
  // Text to Speech
  Future<void> speak(String text, {String? language, double? rate, double? pitch}) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    
    try {
      Logger.info('Speaking: $text');
      
      _isSpeaking = true;
      notifyListeners();
      
      // Set language
      if (language != null && language != _currentLanguage) {
        await _flutterTts.setLanguage(language);
        _currentLanguage = language;
      }
      
      // Set rate
      if (rate != null) {
        await _flutterTts.setSpeechRate(rate);
      }
      
      // Set pitch
      if (pitch != null) {
        await _flutterTts.setPitch(pitch);
      }
      
      // Speak
      final result = await _flutterTts.speak(text);
      
      if (result == 1) {
        // Add to history
        _addToHistory(
          text: text,
          confidence: 1.0,
          type: 'speech_synthesis',
        );
        Logger.info('Speech synthesis started');
      } else {
        _isSpeaking = false;
        Logger.warning('Speech synthesis failed');
        notifyListeners();
      }
    } catch (e) {
      _isSpeaking = false;
      Logger.error('Speech synthesis failed: $e');
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
      Logger.info('Speaking stopped');
      notifyListeners();
    }
  }
  
  Future<void> setVoiceLanguage(String language) async {
    try {
      await _flutterTts.setLanguage(language);
      _currentLanguage = language;
      Logger.info('Voice language set to: $language');
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to set language: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> getAvailableVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      return List<Map<String, dynamic>>.from(voices ?? []);
    } catch (e) {
      Logger.error('Failed to get voices: $e');
      return [];
    }
  }
  
  // Audio Recording
  Future<String?> startRecording() async {
    if (_isRecording) {
      Logger.warning('Already recording');
      return null;
    }
    
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        Logger.error('No recording permission');
        return null;
      }
      
      final recordPath = await _getRecordingPath();
      if (recordPath == null) {
        Logger.error('Failed to get recording path');
        return null;
      }
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: recordPath,
      );
      
      _isRecording = true;
      Logger.info('Recording started: $recordPath');
      notifyListeners();
      
      return recordPath;
    } catch (e) {
      _isRecording = false;
      Logger.error('Recording failed: $e');
      notifyListeners();
      return null;
    }
  }
  
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      Logger.warning('Not recording');
      return null;
    }
    
    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      Logger.info('Recording stopped: $path');
      notifyListeners();
      return path;
    } catch (e) {
      _isRecording = false;
      Logger.error('Failed to stop recording: $e');
      notifyListeners();
      return null;
    }
  }
  
  Future<String?> _getRecordingPath() async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${directory.path}/recording_$timestamp.m4a';
    } catch (e) {
      Logger.error('Failed to get recording path: $e');
      return null;
    }
  }
  
  // Audio Playback
  Future<void> playAudio(String path) async {
    try {
      await _audioPlayer?.setFilePath(path);
      await _audioPlayer?.play();
      Logger.info('Audio playback started: $path');
    } catch (e) {
      Logger.error('Audio playback failed: $e');
      rethrow;
    }
  }
  
  Future<void> stopAudio() async {
    await _audioPlayer?.stop();
    Logger.info('Audio playback stopped');
  }
  
  Future<void> pauseAudio() async {
    await _audioPlayer?.pause();
    Logger.info('Audio playback paused');
  }
  
  Future<void> resumeAudio() async {
    await _audioPlayer?.play();
    Logger.info('Audio playback resumed');
  }
  
  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
    _volume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }
  
  // Translation
  Future<String> translate(String text, String targetLanguage) async {
    try {
      Logger.info('Translating to: $targetLanguage');
      
      _addToHistory(
        text: text,
        confidence: 1.0,
        type: 'translation',
        metadata: {'targetLanguage': targetLanguage},
      );
      
      final translation = await _translateViaAPI(text, targetLanguage);
      return translation;
    } catch (e) {
      Logger.error('Translation failed: $e');
      return text;
    }
  }
  
  Future<String> _translateViaAPI(String text, String targetLanguage) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.synapse.ai/translate'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'targetLanguage': targetLanguage,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['translation'] ?? text;
      }
      
      return text;
    } catch (e) {
      Logger.error('Translation API call failed: $e');
      return text;
    }
  }
  
  // Voice Analysis
  Future<Map<String, dynamic>> analyzeAudio(dynamic audioData) async {
    try {
      Logger.info('Analyzing audio...');
      
      final analysis = {
        'duration': 0.0,
        'sampleRate': 0,
        'channels': 0,
        'features': {
          'pitch': 0.0,
          'energy': 0.0,
          'mfcc': [],
        },
        'sentiment': {
          'valence': 0.5,
          'arousal': 0.5,
        },
        'language': _currentLanguage,
      };
      
      _voiceMetrics['lastAnalysis'] = analysis;
      notifyListeners();
      
      return analysis;
    } catch (e) {
      Logger.error('Audio analysis failed: $e');
      return {'error': e.toString()};
    }
  }
  
  // History
  void _addToHistory({
    required String text,
    required double confidence,
    required String type,
    Map<String, dynamic>? metadata,
  }) {
    final entry = {
      'text': text,
      'confidence': confidence,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      'language': _currentLanguage,
      'metadata': metadata ?? {},
    };
    
    _voiceHistory.insert(0, entry);
    if (_voiceHistory.length > 100) {
      _voiceHistory.removeLast();
    }
  }
  
  List<Map<String, dynamic>> getVoiceHistory() {
    return _voiceHistory;
  }
  
  Map<String, dynamic> getVoiceMetrics() {
    return _voiceMetrics;
  }
  
  void clearHistory() {
    _voiceHistory.clear();
    notifyListeners();
  }
  
  // Cleanup
  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _audioRecorder.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }
}
