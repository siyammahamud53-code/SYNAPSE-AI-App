import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:synapse_ai/providers/app_state.dart';
import 'package:synapse_ai/utils/logger.dart';
import 'package:synapse_ai/models/task.dart';
import 'package:synapse_ai/models/system_status.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:screen_retriever/screen_retriever.dart';

class BackgroundService extends ChangeNotifier {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();
  
  final MethodChannel _nativeChannel = const MethodChannel('com.synapse.ai/native');
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
  final Map<String, Task> _activeTasks = {};
  final List<String> _completedTasks = [];
  final Map<String, DateTime> _taskTimestamps = {};
  
  Timer? _heartbeatTimer;
  Timer? _metricsTimer;
  Timer? _taskProcessorTimer;
  
  // Getters
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get taskQueueLength => _taskQueue.length;
  int get activeTaskCount => _activeTasks.length;
  int get completedTaskCount => _completedTasks.length;
  
  // Initialization
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Logger.info('Initializing BackgroundService...');
      
      // Check permissions
      await _checkPermissions();
      
      // Start monitoring
      _startMonitoring();
      
      // Start task processor
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
      // Check accessibility
      final isAccessibilityEnabled = await _nativeChannel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
      _isAccessibilityEnabled = isAccessibilityEnabled;
      
      // Check overlay
      final isOverlayEnabled = await _nativeChannel.invokeMethod<bool>('isOverlayEnabled') ?? false;
      _isOverlayEnabled = isOverlayEnabled;
      
      // Check battery optimization
      final isBatteryOptimizationIgnored = await _nativeChannel.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? false;
      _isBatteryOptimizationIgnored = isBatteryOptimizationIgnored;
      
      // Request permissions if needed
      if (!isAccessibilityEnabled) {
        Logger.warning('Accessibility service not enabled');
        await _nativeChannel.invokeMethod('requestAccessibility');
      }
      
      if (!isOverlayEnabled) {
        Logger.warning('Overlay permission not granted');
        await _nativeChannel.invokeMethod('requestOverlay');
      }
      
      if (!isBatteryOptimizationIgnored) {
        Logger.warning('Battery optimization not ignored');
        await _nativeChannel.invokeMethod('requestIgnoreBatteryOptimization');
      }
    } catch (e) {
      Logger.error('Permission check failed: $e');
    }
  }
  
  void _startMonitoring() {
    // Battery monitoring
    _battery.batteryState.listen((state) {
      _isCharging = state == BatteryState.charging || 
                    state == BatteryState.full;
      notifyListeners();
    });
    
    _battery.batteryLevel.listen((level) {
      _batteryLevel = level;
      notifyListeners();
    });
    
    // Connectivity monitoring
    _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) {
        _connectivityStatus = 'disconnected';
      } else {
        _connectivityStatus = 'connected';
      }
      notifyListeners();
    });
    
    // Heartbeat timer
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
    
    // Metrics timer
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updateMetrics(),
    );
  }
  
  void _startTaskProcessor() {
    _taskProcessorTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _processNextTask(),
    );
  }
  
  Future<void> _sendHeartbeat() async {
    if (!_isRunning) return;
    
    try {
      final heartbeat = {
        'type': 'background_heartbeat',
        'timestamp': DateTime.now().toIso8601String(),
        'tasks': {
          'active': _activeTasks.length,
          'queued': _taskQueue.length,
          'completed': _completedTasks.length,
        },
        'status': {
          'memory': _memoryUsage,
          'cpu': _cpuUsage,
          'battery': _batteryLevel,
          'charging': _isCharging,
          'connectivity': _connectivityStatus,
        },
      };
      
      // Send through native channel
      await _nativeChannel.invokeMethod('sendHeartbeat', heartbeat);
      
      // Update app state
      final appState = AppState();
      appState.updateMetric('heartbeat', heartbeat);
    } catch (e) {
      Logger.error('Heartbeat failed: $e');
    }
  }
  
  Future<void> _updateMetrics() async {
    try {
      // Get memory usage
      final memInfo = await _getMemoryInfo();
      _memoryUsage = memInfo['used'] ?? 0;
      
      // Get CPU usage
      final cpuInfo = await _getCpuInfo();
      _cpuUsage = cpuInfo['usage'] ?? 0;
      
      // Update app state
      final appState = AppState();
      appState.memoryUsage = _memoryUsage / 1024 / 1024; // Convert to MB
      appState.cpuUsage = _cpuUsage.toDouble();
      appState.batteryLevel = _batteryLevel;
      appState.isCharging = _isCharging;
      
      notifyListeners();
    } catch (e) {
      Logger.error('Metrics update failed: $e');
    }
  }
  
  Future<Map<String, dynamic>> _getMemoryInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _nativeChannel.invokeMethod('getMemoryInfo');
        return Map<String, dynamic>.from(info ?? {});
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Use system info for desktop
        // Placeholder
        return {'total': 0, 'used': 0, 'free': 0};
      }
      return {'total': 0, 'used': 0, 'free': 0};
    } catch (e) {
      return {'total': 0, 'used': 0, 'free': 0};
    }
  }
  
  Future<Map<String, dynamic>> _getCpuInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _nativeChannel.invokeMethod('getCpuInfo');
        return Map<String, dynamic>.from(info ?? {});
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Use system info for desktop
        // Placeholder
        return {'usage': 0};
      }
      return {'usage': 0};
    } catch (e) {
      return {'usage': 0};
    }
  }
  
  Future<void> _processNextTask() async {
    if (_isPaused || _taskQueue.isEmpty) return;
    
    final taskData = _taskQueue.removeAt(0);
    final String taskId = taskData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    try {
      Logger.info('Processing task: $taskId');
      
      final task = Task.fromJson(taskData);
      _activeTasks[taskId] = task;
      
      // Execute task based on type
      final result = await _executeTask(task);
      
      // Mark as completed
      _activeTasks.remove(taskId);
      _completedTasks.add(taskId);
      _taskTimestamps[taskId] = DateTime.now();
      
      Logger.info('Task completed: $taskId');
      
      // Update app state
      final appState = AppState();
      appState.completeTask(task.type);
      
      // Send result back
      await _nativeChannel.invokeMethod('taskCompleted', {
        'taskId': taskId,
        'result': result,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('Task failed: $taskId - $e', stackTrace);
      
      _activeTasks.remove(taskId);
      
      // Update app state
      final appState = AppState();
      appState.failTask(taskId, e.toString());
      
      // Send failure
      await _nativeChannel.invokeMethod('taskFailed', {
        'taskId': taskId,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      notifyListeners();
    }
  }
  
  Future<Map<String, dynamic>> _executeTask(Task task) async {
    switch (task.type) {
      case 'voice':
        return await _executeVoiceTask(task);
      case 'vision':
        return await _executeVisionTask(task);
      case 'call':
        return await _executeCallTask(task);
      case 'system':
        return await _executeSystemTask(task);
      case 'automation':
        return await _executeAutomationTask(task);
      default:
        throw Exception('Unknown task type: ${task.type}');
    }
  }
  
  Future<Map<String, dynamic>> _executeVoiceTask(Task task) async {
    final params = task.parameters;
    final action = params['action'] ?? 'speak';
    
    switch (action) {
      case 'speak':
        // Use TTS
        return {'status': 'speaking', 'text': params['text']};
      case 'listen':
        // Use STT
        return {'status': 'listening', 'transcript': 'Placeholder'};
      default:
        throw Exception('Unknown voice action: $action');
    }
  }
  
  Future<Map<String, dynamic>> _executeVisionTask(Task task) async {
    final params = task.parameters;
    final action = params['action'] ?? 'capture';
    
    switch (action) {
      case 'capture':
        // Capture image
        return {'status': 'captured', 'path': '/sdcard/synapse_capture.jpg'};
      case 'process':
        // Process image
        return {'status': 'processed', 'result': {}};
      default:
        throw Exception('Unknown vision action: $action');
    }
  }
  
  Future<Map<String, dynamic>> _executeCallTask(Task task) async {
    final params = task.parameters;
    final action = params['action'] ?? 'make';
    
    switch (action) {
      case 'make':
        // Make call
        return {'status': 'calling', 'number': params['phoneNumber']};
      case 'answer':
        // Answer call
        return {'status': 'answered'};
      default:
        throw Exception('Unknown call action: $action');
    }
  }
  
  Future<Map<String, dynamic>> _executeSystemTask(Task task) async {
    final params = task.parameters;
    final action = params['action'] ?? 'status';
    
    switch (action) {
      case 'status':
        return await getSystemStatus();
      case 'restart':
        // Restart services
        return {'status': 'restarted'};
      default:
        throw Exception('Unknown system action: $action');
    }
  }
  
  Future<Map<String, dynamic>> _executeAutomationTask(Task task) async {
    final params = task.parameters;
    final action = params['action'] ?? 'task';
    
    switch (action) {
      case 'task':
        // Execute automation task
        return {'status': 'executed', 'result': {}};
      default:
        throw Exception('Unknown automation action: $action');
    }
  }
  
  // Public API
  Future<void> startServices() async {
    if (_isRunning) return;
    
    try {
      Logger.info('Starting background services...');
      
      // Start native service
      await _nativeChannel.invokeMethod('startService');
      
      _isRunning = true;
      _isPaused = false;
      
      // Register periodic tasks
      await Workmanager().registerPeriodicTask(
        'synapse_ai_background',
        'backgroundTask',
        frequency: Duration(hours: 1),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
      
      Logger.info('Background services started');
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to start services: $e');
      rethrow;
    }
  }
  
  Future<void> stopServices() async {
    if (!_isRunning) return;
    
    try {
      Logger.info('Stopping background services...');
      
      // Stop native service
      await _nativeChannel.invokeMethod('stopService');
      
      // Cancel workmanager tasks
      await Workmanager().cancelAll();
      
      _isRunning = false;
      _isPaused = false;
      
      Logger.info('Background services stopped');
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to stop services: $e');
      rethrow;
    }
  }
  
  Future<void> pauseServices() async {
    if (!_isRunning || _isPaused) return;
    
    _isPaused = true;
    Logger.info('Background services paused');
    notifyListeners();
  }
  
  Future<void> resumeServices() async {
    if (!_isRunning || !_isPaused) return;
    
    _isPaused = false;
    Logger.info('Background services resumed');
    notifyListeners();
  }
  
  Future<void> restartServices() async {
    await stopServices();
    await Future.delayed(const Duration(seconds: 2));
    await startServices();
  }
  
  Future<Map<String, dynamic>> getSystemStatus() async {
    return {
      'running': _isRunning,
      'paused': _isPaused,
      'memory': _memoryUsage,
      'cpu': _cpuUsage,
      'battery': _batteryLevel,
      'charging': _isCharging,
      'connectivity': _connectivityStatus,
      'tasks': {
        'active': _activeTasks.length,
        'queued': _taskQueue.length,
        'completed': _completedTasks.length,
      },
      'permissions': {
        'accessibility': _isAccessibilityEnabled,
        'overlay': _isOverlayEnabled,
        'batteryOptimization': _isBatteryOptimizationIgnored,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  Future<void> addTask(Map<String, dynamic> task) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    task['id'] = taskId;
    task['addedAt'] = DateTime.now().toIso8601String();
    
    _taskQueue.add(task);
    
    // Update app state
    final appState = AppState();
    appState.addTask(taskId);
    
    Logger.info('Task added to queue: $taskId');
    notifyListeners();
  }
  
  Future<void> processBackgroundQueue() async {
    while (_taskQueue.isNotEmpty) {
      await _processNextTask();
    }
  }
  
  Future<void> executeTask(String taskName, Map<String, dynamic> params) async {
    final task = {
      'type': 'automation',
      'name': taskName,
      'parameters': params,
    };
    await addTask(task);
  }
  
  Future<void> scheduleTask(String taskName, Map<String, dynamic> schedule) async {
    // Schedule task using WorkManager
    await Workmanager().registerOneOffTask(
      'synapse_ai_scheduled_$taskName',
      'scheduledTask',
      inputData: {
        'taskName': taskName,
        'schedule': jsonEncode(schedule),
      },
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    
    Logger.info('Task scheduled: $taskName');
  }
  
  Future<void> cancelTask(String taskId) async {
    _taskQueue.removeWhere((task) => task['id'] == taskId);
    _activeTasks.remove(taskId);
    
    Logger.info('Task cancelled: $taskId');
    notifyListeners();
  }
  
  Future<void> clearTaskQueue() async {
    _taskQueue.clear();
    Logger.info('Task queue cleared');
    notifyListeners();
  }
  
  // Cleanup
  void dispose() {
    _heartbeatTimer?.cancel();
    _metricsTimer?.cancel();
    _taskProcessorTimer?.cancel();
    super.dispose();
  }
}
