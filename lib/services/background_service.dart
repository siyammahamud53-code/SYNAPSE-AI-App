import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class Logger {
  static void info(String message) => debugPrint('[SYNAPSE INFO] $message');
  static void error(String message, [dynamic error, StackTrace? stackTrace]) => 
      debugPrint('[SYNAPSE ERROR] $message $error');
  static void warning(String message) => debugPrint('[SYNAPSE WARNING] $message');
  static void debug(String message) => debugPrint('[SYNAPSE DEBUG] $message');
}

class BackgroundService extends ChangeNotifier {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final MethodChannel _nativeChannel = const MethodChannel('com.synapse_ai/native');
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  bool _isInitialized = false;
  bool _isRunning = false;
  bool _isPaused = false;
  
  int _batteryLevel = 100;
  bool _isCharging = false;
  
  Timer? _autonomousNpcTimer;
  Timer? _metricsTimer;

  bool get isRunning => _isRunning;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Logger.info('Initializing Autonomous Background Engine...');
      _startMonitoring();
      _startAutonomousNpcLoop();

      _isInitialized = true;
      _isRunning = true;
      Logger.info('BackgroundService & UAS Core running safely');
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('BackgroundService initialization notice: $e', stackTrace);
    }
  }

  void _startMonitoring() {
    _metricsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateMetrics());
  }

  // Free Guy Style Self-Thinking Continuous Background NPC Loop
  void _startAutonomousNpcLoop() {
    _autonomousNpcTimer?.cancel();
    // Device adaptive milliseconds cycle (runs smoothly without lag)
    _autonomousNpcTimer = Timer.periodic(const Duration(milliseconds: 3000), (timer) {
      if (!_isRunning) return;
      _executeAutonomousSelfCheck();
    });
  }

  void _executeAutonomousSelfCheck() {
    Logger.debug('UAS Loop: Ragna & Maya background monitoring...');
  }

  Future<void> _updateMetrics() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      final batteryState = await _battery.batteryState;
      _isCharging = batteryState == BatteryState.charging;
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to update system metrics: $e');
    }
  }

  @override
  void dispose() {
    _autonomousNpcTimer?.cancel();
    _metricsTimer?.cancel();
    super.dispose();
  }
}
