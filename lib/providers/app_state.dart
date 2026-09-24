import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ActivePersona { ragna, maya }

class DeviceInfo {
  final String deviceId;
  DeviceInfo({required this.deviceId});
}

class SystemStatus {
  static SystemStatus initial() => SystemStatus();
}

class AppState extends ChangeNotifier {
  static const String _prefsKey = 'synapse_ai_state';

  // Flutter TTS Engine
  final FlutterTts _flutterTts = FlutterTts();

  // Hugging Face Endpoint
  final String _hfEndpoint = "https://siyammahamud53-synapse-ai-core.hf.space/chat";
  
  // Environment variables injection (Build-time secure fetch)
  final String _groqApiKey = const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  final String _geminiApiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  bool _isInitialized = false;
  bool _isOnboardingComplete = false;
  bool _isServiceRunning = false;
  bool _isVoiceActive = false;
  bool _isVisionActive = false;
  bool _isCallActive = false;
  bool _isConnected = false;

  ActivePersona _currentPersona = ActivePersona.ragna;
  String _activeSpeechContext = "JARVIS Neural Core Active";
  bool _isNpcSelfThinking = false;
  int _deviceFpsLimit = 60;

  String _sessionId = '';
  String _userId = '';
  String _deviceId = '';

  DateTime _lastActive = DateTime.now();
  DateTime _startTime = DateTime.now();

  DeviceInfo? _deviceInfo;
  SystemStatus _systemStatus = SystemStatus.initial();

  double _memoryUsage = 0.0;
  double _cpuUsage = 0.0;
  int _batteryLevel = 100;
  bool _isCharging = false;

  int _totalTasks = 0;
  int _completedTasks = 0;
  int _failedTasks = 0;
  double _successRate = 0.0;

  String _currentActivity = 'Autonomous Monitoring Active';
  String _lastError = '';
  List<String> _recentTasks = [];
  Map<String, dynamic> _metrics = {};

  AppState() {
    _loadState();
    _initTts();
  }

  void _initTts() async {
    try {
      await _flutterTts.setLanguage("bn-BD");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.55);
    } catch (e) {
      debugPrint("TTS Setup notice: $e");
    }
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isServiceRunning => _isServiceRunning;
  bool get isVoiceActive => _isVoiceActive;
  bool get isVisionActive => _isVisionActive;
  bool get isCallActive => _isCallActive;
  bool get isConnected => _isConnected;
  ActivePersona get currentPersona => _currentPersona;
  String get activeSpeechContext => _activeSpeechContext;
  bool get isNpcSelfThinking => _isNpcSelfThinking;
  int get deviceFpsLimit => _deviceFpsLimit;

  String get sessionId => _sessionId;
  String get userId => _userId;
  String get deviceId => _deviceId;
  DateTime get lastActive => _lastActive;
  DateTime get startTime => _startTime;
  DeviceInfo? get deviceInfo => _deviceInfo;
  SystemStatus get systemStatus => _systemStatus;
  double get memoryUsage => _memoryUsage;
  double get cpuUsage => _cpuUsage;
  int get batteryLevel => _batteryLevel;
  bool get isCharging => _isCharging;
  int get totalTasks => _totalTasks;
  int get completedTasks => _completedTasks;
  int get failedTasks => _failedTasks;
  double get successRate => _successRate;
  String get currentActivity => _currentActivity;
  String get lastError => _lastError;
  List<String> _getRecentTasks() => _recentTasks;
  List<String> get recentTasks => _recentTasks;
  Map<String, dynamic> get metrics => _metrics;

  Duration get uptime => DateTime.now().difference(_startTime);

  void processIntelligentPersonaRouting(String userQuery) {
    final text = userQuery.toLowerCase();
    if (text.contains('maya') || text.contains('মায়া')) {
      if (text.contains('ragna') || text.contains('রাগনা')) {
        _activeSpeechContext = "Ragna and Maya dual-core processing engaged.";
      } else {
        _currentPersona = ActivePersona.maya;
        _activeSpeechContext = "Maya voice persona activated.";
      }
    } else if (text.contains('ragna') || text.contains('রাগনা')) {
      _currentPersona = ActivePersona.ragna;
      _activeSpeechContext = "Ragna core activated. Tactical directive standing by.";
    }
    notifyListeners();
  }

  Future<void> sendUserMessage(String userQuery) async {
    processIntelligentPersonaRouting(userQuery);

    _activeSpeechContext = "Processing Request...";
    notifyListeners();

    String? aiResponse;

    // Fast-Pass 1: Direct Ultra-Fast Groq Pipeline
    if (_groqApiKey.isNotEmpty) {
      try {
        final groqRes = await http.post(
          Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_groqApiKey'
          },
          body: jsonEncode({
            "model": "llama-3.3-70b-versatile",
            "messages": [
              {
                "role": "system", 
                "content": _currentPersona == ActivePersona.ragna 
                    ? "You are Ragna, an advanced real-life JARVIS AI system assistant. Answer clearly, accurately, concisely, and naturally." 
                    : "You are Maya, an intelligent, empathetic female AI core. Answer clearly and naturally."
              },
              {"role": "user", "content": userQuery}
            ],
            "max_tokens": 512,
            "temperature": 0.7
          }),
        ).timeout(const Duration(milliseconds: 2500));

        if (groqRes.statusCode == 200) {
          final data = jsonDecode(groqRes.body);
          aiResponse = data['choices'][0]['message']['content'];
        }
      } catch (e) {
        debugPrint("Groq ultra-fast pass bypass: $e");
      }
    }

    // Fast-Pass 2: Direct Gemini Pipeline
    if (aiResponse == null && _geminiApiKey.isNotEmpty) {
      try {
        final geminiUrl = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey");
        final geminiRes = await http.post(
          geminiUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [{"parts": [{"text": userQuery}]}]
          }),
        ).timeout(const Duration(milliseconds: 3000));

        if (geminiRes.statusCode == 200) {
          final data = jsonDecode(geminiRes.body);
          aiResponse = data['candidates'][0]['content']['parts'][0]['text'];
        }
      } catch (e) {
        debugPrint("Gemini direct bypass: $e");
      }
    }

    // Fast-Pass 3: Hugging Face Fallback
    if (aiResponse == null) {
      try {
        final response = await http.post(
          Uri.parse(_hfEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': userQuery,
            'persona': _currentPersona == ActivePersona.ragna ? 'ragna' : 'maya'
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          aiResponse = data['response'] ?? data['message'];
        }
      } catch (e) {
        debugPrint("HF Server offline or sleeping.");
      }
    }

    if (aiResponse != null && aiResponse.isNotEmpty) {
      _activeSpeechContext = aiResponse;
      notifyListeners();
      await speak(aiResponse);
    } else {
      _activeSpeechContext = "সার্ভার সংযোগে সমস্যা হচ্ছে। গিটহাব সিক্রেটস চেক করুন।";
      notifyListeners();
      await speak("সংযোগ সমস্যা দেখা দিয়েছে।");
    }
  }

  void updateNpcSelfThinking(bool isThinking, String thoughtContext) {
    _isNpcSelfThinking = isThinking;
    _activeSpeechContext = thoughtContext;
    notifyListeners();
  }

  void setDeviceFpsLimit(int fps) {
    _deviceFpsLimit = fps;
    notifyListeners();
  }

  set isOnboardingComplete(bool value) {
    _isOnboardingComplete = value;
    _saveState();
    notifyListeners();
  }

  set isServiceRunning(bool value) {
    _isServiceRunning = value;
    _saveState();
    notifyListeners();
  }

  set isVoiceActive(bool value) {
    _isVoiceActive = value;
    notifyListeners();
  }

  set isVisionActive(bool value) {
    _isVisionActive = value;
    notifyListeners();
  }

  set isCallActive(bool value) {
    _isCallActive = value;
    notifyListeners();
  }

  set isConnected(bool value) {
    _isConnected = value;
    notifyListeners();
  }

  set sessionId(String value) {
    _sessionId = value;
    notifyListeners();
  }

  set userId(String value) {
    _userId = value;
    notifyListeners();
  }

  set deviceId(String value) {
    _deviceId = value;
    notifyListeners();
  }

  set memoryUsage(double value) {
    _memoryUsage = value;
    notifyListeners();
  }

  set cpuUsage(double value) {
    _cpuUsage = value;
    notifyListeners();
  }

  set batteryLevel(int value) {
    _batteryLevel = value;
    notifyListeners();
  }

  set isCharging(bool value) {
    _isCharging = value;
    notifyListeners();
  }

  set currentActivity(String value) {
    _currentActivity = value;
    notifyListeners();
  }

  set lastError(String value) {
    _lastError = value;
    notifyListeners();
  }

  void initialize() {
    _isInitialized = true;
    _startTime = DateTime.now();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    notifyListeners();
  }

  void updateDeviceInfo(DeviceInfo info) {
    _deviceInfo = info;
    _deviceId = info.deviceId;
    notifyListeners();
  }

  void updateSystemStatus(SystemStatus status) {
    _systemStatus = status;
    notifyListeners();
  }

  void addTask(String task) {
    _totalTasks++;
    _recentTasks.add(task);
    if (_recentTasks.length > 50) {
      _recentTasks.removeAt(0);
    }
    _lastActive = DateTime.now();
    notifyListeners();
  }

  void completeTask(String task) {
    _completedTasks++;
    _successRate = _totalTasks > 0 ? (_completedTasks / _totalTasks) * 100 : 0.0;
    _lastActive = DateTime.now();
    notifyListeners();
  }

  void failTask(String task, String error) {
    _failedTasks++;
    _lastError = error;
    _successRate = _totalTasks > 0 ? (_completedTasks / _totalTasks) * 100 : 0.0;
    _lastActive = DateTime.now();
    notifyListeners();
  }

  void updateMetric(String key, dynamic value) {
    _metrics[key] = value;
    notifyListeners();
  }

  void clearMetrics() {
    _metrics.clear();
    notifyListeners();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      if (jsonString != null) {
        final Map<String, dynamic> data = jsonDecode(jsonString);
        _isOnboardingComplete = data['onboardingComplete'] ?? false;
        _userId = data['userId'] ?? '';
        _deviceId = data['deviceId'] ?? '';
        _sessionId = data['sessionId'] ?? '';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading state: $e');
    }
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'onboardingComplete': _isOnboardingComplete,
        'userId': _userId,
        'deviceId': _deviceId,
        'sessionId': _sessionId,
        'lastSaved': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving state: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _saveState();
    super.dispose();
  }
}
