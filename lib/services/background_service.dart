import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:screen_retriever/screen_retriever.dart';

// Inline Logger Class (যাতে অন্য কোনো ফাইলের ওপর নির্ভর করতে না হয়)
class Logger {
  static void info(String message) => debugPrint('[INFO] $message');
  static void error(String message, [dynamic error, StackTrace? stackTrace]) => 
      debugPrint('[ERROR] $message $error');
  static void warning(String message) => debugPrint('[WARNING] $message');
  static void debug(String message) => debugPrint('[DEBUG] $message');
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
  bool _isAccessibilityEnabled = false;
  bool _isOverlayEnabled = false;
  bool _isBatteryOptimizationIgnored = false;

  int _memoryUsage = 0;
  int _cpuUsage = 0;
  int _batteryLevel = 0;
  bool _isCharging = false;
  String _connectivityStatus = 'unknown';

  final List<Map<String, dynamic>> _taskQueue = [];
  final List<String> _activeTasks = [];
  final List<String> _completedTasks = [];
  final Map<String, DateTime> _taskTimestamps = {};

  Timer? _heartbeatTimer;
  Timer? _metricsTimer;
  Timer? _taskProcessorTimer;

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get taskQueueLength => _taskQueue.length;
  int get activeTaskCount => _activeTasks.length;
  int get completedTaskCount => _completedTasks.length;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Logger.info('Initializing BackgroundService...');
      await _checkPermissions();
      _startMonitoring();
      _startTaskProcessor();

      _isInitialized = true;
      Logger.info('BackgroundService initialized successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('BackgroundService initialization failed: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> _checkPermissions() async {
    try {
      _isAccessibilityEnabled = await _nativeChannel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
      _isOverlayEnabled = await _nativeChannel.invokeMethod<bool>('isOverlayEnabled') ?? false;
      _isBatteryOptimizationIgnored = await _nativeChannel.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
    } catch (e) {
      Logger.error('Failed to check permissions: $e');
    }
  }

  void _startMonitoring() {
    _metricsTimer = Timer.periodic(const Duration(seconds: 10), (_) => _updateMetrics());
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
  }

  Future<void> _updateMetrics() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      final batteryState = await _battery.batteryState;
      _isCharging = batteryState == BatteryState.charging;
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to update metrics: $e');
    }
  }

  void _sendHeartbeat() {
    Logger.info('Background service heartbeat');
  }

  void _startTaskProcessor() {
    _taskProcessorTimer = Timer.periodic(const Duration(seconds: 5), (_) => _processQueue());
  }

  Future<void> _processQueue() async {
    if (_isPaused || _taskQueue.isEmpty) return;

    final task = _taskQueue.removeAt(0);
    final taskId = task['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    try {
      _activeTasks.add(taskId);
      Logger.info('Task started: $taskId');

      await Future.delayed(const Duration(seconds: 1));

      _activeTasks.remove(taskId);
      _completedTasks.add(taskId);
      Logger.info('Task completed: $taskId');
    } catch (e) {
      _activeTasks.remove(taskId);
      Logger.error('Task failed: $taskId - $e');
    }
  }

  Future<Map<String, dynamic>> getSystemStatus() async {
    return {
      'isRunning': _isRunning,
      'isPaused': _isPaused,
      'batteryLevel': _batteryLevel,
      'isCharging': _isCharging,
      'queueLength': _taskQueue.length,
      'activeTasks': _activeTasks.length,
      'completedTasks': _completedTasks.length,
    };
  }

  Future<void> startServices() async {
    _isRunning = true;
    _isPaused = false;
    Logger.info('Background services started');
    notifyListeners();
  }

  Future<void> stopServices() async {
    _isRunning = false;
    Logger.info('Background services stopped');
    notifyListeners();
  }

  Future<void> restartServices() async {
    await stopServices();
    await startServices();
  }

  Future<dynamic> executeTask(String taskName, Map<String, dynamic> params) async {
    Logger.info('Task scheduled: $taskName');
    _taskQueue.add({'id': taskName, 'params': params});
    return true;
  }

  Future<void> scheduleTask(String taskName, Map<String, dynamic> schedule) async {
    Logger.info('Task scheduled with timing: $taskName');
  }

  Future<void> cancelTask(String taskId) async {
    _taskQueue.removeWhere((task) => task['id'] == taskId);
    Logger.info('Task cancelled: $taskId');
  }

  void clearQueue() {
    _taskQueue.clear();
    Logger.info('Task queue cleared');
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _metricsTimer?.cancel();
    _taskProcessorTimer?.cancel();
    super.dispose();
  }
}
