import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_ai/models/device_info.dart';
import 'package:synapse_ai/models/system_status.dart';

class AppState extends ChangeNotifier {
  static const String _prefsKey = 'synapse_ai_state';
  
  bool _isInitialized = false;
  bool _isOnboardingComplete = false;
  bool _isServiceRunning = false;
  bool _isVoiceActive = false;
  bool _isVisionActive = false;
  bool _isCallActive = false;
  bool _isConnected = false;
  
  String _sessionId = '';
  String _userId = '';
  String _deviceId = '';
  
  DateTime _lastActive = DateTime.now();
  DateTime _startTime = DateTime.now();
  
  DeviceInfo? _deviceInfo;
  SystemStatus _systemStatus = SystemStatus.initial();
  
  double _memoryUsage = 0.0;
  double _cpuUsage = 0.0;
  int _batteryLevel = 0;
  bool _isCharging = false;
  
  int _totalTasks = 0;
  int _completedTasks = 0;
  int _failedTasks = 0;
  double _successRate = 0.0;
  
  String _currentActivity = 'Idle';
  String _lastError = '';
  List<String> _recentTasks = [];
  Map<String, dynamic> _metrics = {};
  
  AppState() {
    _loadState();
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isServiceRunning => _isServiceRunning;
  bool get isVoiceActive => _isVoiceActive;
  bool get isVisionActive => _isVisionActive;
  bool get isCallActive => _isCallActive;
  bool get isConnected => _isConnected;
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
  List<String> get recentTasks => _recentTasks;
  Map<String, dynamic> get metrics => _metrics;
  
  Duration get uptime => DateTime.now().difference(_startTime);
  
  // Setters
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
  
  // Methods
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
  
  void reset() {
    _isOnboardingComplete = false;
    _isServiceRunning = false;
    _isVoiceActive = false;
    _isVisionActive = false;
    _isCallActive = false;
    _isConnected = false;
    _sessionId = '';
    _userId = '';
    _deviceId = '';
    _lastActive = DateTime.now();
    _memoryUsage = 0.0;
    _cpuUsage = 0.0;
    _batteryLevel = 0;
    _isCharging = false;
    _totalTasks = 0;
    _completedTasks = 0;
    _failedTasks = 0;
    _successRate = 0.0;
    _currentActivity = 'Idle';
    _lastError = '';
    _recentTasks = [];
    _metrics = {};
    _saveState();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _saveState();
    super.dispose();
  }
}
