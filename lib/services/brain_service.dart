import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:synapse_ai/providers/app_state.dart';
import 'package:synapse_ai/services/background_service.dart';
import 'package:synapse_ai/services/call_service.dart';
import 'package:synapse_ai/services/vision_service.dart';
import 'package:synapse_ai/services/voice_engine.dart';
import 'package:synapse_ai/models/brain_response.dart';
import 'package:synapse_ai/models/command.dart';
import 'package:synapse_ai/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class BrainService extends ChangeNotifier {
  static final BrainService _instance = BrainService._internal();
  factory BrainService() => _instance;
  BrainService._internal();
  
  static const String WS_URL = 'wss://siyammahamud53-synapse-ai-core.hf.space/ws';
  static const int RECONNECT_DELAY = 5000;
  static const int MAX_RECONNECT_ATTEMPTS = 10;
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _stateSyncTimer;
  
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isProcessing = false;
  int _reconnectAttempts = 0;
  String _sessionId = '';
  String _deviceId = '';
  
  final List<Command> _commandQueue = [];
  final Map<String, DateTime> _commandTimestamps = {};
  final Map<String, BrainResponse> _responseCache = {};
  
  final BackgroundService _backgroundService = BackgroundService();
  final VoiceEngine _voiceEngine = VoiceEngine();
  final VisionService _visionService = VisionService();
  final CallService _callService = CallService();
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isProcessing => _isProcessing;
  int get queueLength => _commandQueue.length;
  
  // Initialization
  Future<void> initialize() async {
    try {
      Logger.info('Initializing BrainService...');
      
      // Load session data
      final prefs = await SharedPreferences.getInstance();
      _sessionId = prefs.getString('brain_session_id') ?? 
                   DateTime.now().millisecondsSinceEpoch.toString();
      _deviceId = prefs.getString('device_id') ?? 'synapse_ai_device';
      
      // Setup connectivity listener
      Connectivity().onConnectivityChanged.listen((results) {
        if (results.contains(ConnectivityResult.none)) {
          _handleDisconnect();
        } else {
          _attemptReconnect();
        }
      });
      
      // Start state sync timer
      _stateSyncTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _syncSystemState(),
      );
      
      // Connect to WebSocket
      await connect();
      
      Logger.info('BrainService initialized successfully');
    } catch (e, stackTrace) {
      Logger.error('BrainService initialization failed: $e', stackTrace);
      rethrow;
    }
  }
  
  // WebSocket Connection
  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    
    try {
      _isConnecting = true;
      Logger.info('Connecting to WebSocket: $WS_URL');
      
      _channel = WebSocketChannel.connect(
        Uri.parse(WS_URL),
        protocols: ['synapse-ai'],
      );
      
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: _handleError,
      );
      
      // Send connection handshake
      _sendHandshake();
      
      // Start heartbeat
      _startHeartbeat();
      
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      
      Logger.info('WebSocket connected successfully');
      notifyListeners();
    } catch (e) {
      _isConnecting = false;
      Logger.error('WebSocket connection failed: $e');
      _attemptReconnect();
    }
  }
  
  void _sendHandshake() {
    final handshake = {
      'type': 'handshake',
      'clientId': _deviceId,
      'sessionId': _sessionId,
      'timestamp': DateTime.now().toIso8601String(),
      'version': '3.0.0',
      'capabilities': {
        'voice': true,
        'vision': true,
        'call': true,
        'background': true,
        'accessibility': true,
      },
    };
    _sendMessage(handshake);
  }
  
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_isConnected) {
          _sendMessage({
            'type': 'heartbeat',
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      },
    );
  }
  
  void _sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        Logger.error('Failed to send message: $e');
        _handleDisconnect();
      }
    }
  }
  
  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> message = jsonDecode(data);
      final String type = message['type'] ?? 'unknown';
      
      switch (type) {
        case 'handshake_ack':
          _handleHandshakeAck(message);
          break;
        case 'command':
          _handleCommand(message);
          break;
        case 'response':
          _handleResponse(message);
          break;
        case 'notification':
          _handleNotification(message);
          break;
        case 'error':
          _handleErrorMessage(message);
          break;
        case 'heartbeat_ack':
          _handleHeartbeatAck(message);
          break;
        default:
          Logger.warning('Unknown message type: $type');
      }
    } catch (e) {
      Logger.error('Message handling failed: $e');
    }
  }
  
  void _handleHandshakeAck(Map<String, dynamic> message) {
    _sessionId = message['sessionId'] ?? _sessionId;
    Logger.info('Handshake acknowledged: $_sessionId');
    notifyListeners();
  }
  
  void _handleCommand(Map<String, dynamic> message) {
    final command = Command.fromJson(message);
    Logger.info('Received command: ${command.id} - ${command.type}');
    
    // Process command in background
    _processCommand(command);
  }
  
  void _handleResponse(Map<String, dynamic> message) {
    final response = BrainResponse.fromJson(message);
    Logger.info('Received response: ${response.id}');
    
    // Cache response
    _responseCache[response.id] = response;
    
    // Process response
    _processResponse(response);
  }
  
  void _handleNotification(Map<String, dynamic> message) {
    final String event = message['event'] ?? 'unknown';
    final Map<String, dynamic> data = message['data'] ?? {};
    
    Logger.info('Notification: $event');
    
    switch (event) {
      case 'system_state':
        _updateSystemState(data);
        break;
      case 'voice_analysis':
        _handleVoiceAnalysis(data);
        break;
      case 'vision_analysis':
        _handleVisionAnalysis(data);
        break;
      case 'call_event':
        _handleCallEvent(data);
        break;
      default:
        Logger.warning('Unknown notification: $event');
    }
  }
  
  void _handleErrorMessage(Map<String, dynamic> message) {
    final String error = message['error'] ?? 'Unknown error';
    final String? code = message['code'];
    Logger.error('Server error: $error (Code: $code)');
    
    // Update app state
    final appState = AppState();
    appState.lastError = error;
  }
  
  void _handleHeartbeatAck(Map<String, dynamic> message) {
    // Heartbeat acknowledged
    Logger.debug('Heartbeat acknowledged');
  }
  
  void _handleDisconnect() {
    if (_isConnected) {
      _isConnected = false;
      _heartbeatTimer?.cancel();
      _subscription?.cancel();
      _channel?.sink.close();
      
      Logger.warning('WebSocket disconnected');
      notifyListeners();
      
      _attemptReconnect();
    }
  }
  
  void _handleError(dynamic error) {
    Logger.error('WebSocket error: $error');
    _handleDisconnect();
  }
  
  void _attemptReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    
    if (_reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      _reconnectAttempts++;
      Logger.info('Attempting reconnect ${_reconnectAttempts}/$MAX_RECONNECT_ATTEMPTS');
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: _reconnectAttempts * 2), () {
        connect();
      });
    } else {
      Logger.error('Max reconnect attempts reached');
    }
  }
  
  // Command Processing
  Future<void> _processCommand(Command command) async {
    _isProcessing = true;
    notifyListeners();
    
    try {
      switch (command.type) {
        case CommandType.voice:
          await _handleVoiceCommand(command);
          break;
        case CommandType.vision:
          await _handleVisionCommand(command);
          break;
        case CommandType.call:
          await _handleCallCommand(command);
          break;
        case CommandType.system:
          await _handleSystemCommand(command);
          break;
        case CommandType.automation:
          await _handleAutomationCommand(command);
          break;
        default:
          Logger.warning('Unknown command type: ${command.type}');
      }
      
      // Send completion
      _sendCommandCompletion(command.id, true);
    } catch (e, stackTrace) {
      Logger.error('Command processing failed: $e', stackTrace);
      _sendCommandCompletion(command.id, false, e.toString());
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
  
  Future<void> _handleVoiceCommand(Command command) async {
    final params = command.parameters;
    final action = params['action'] ?? 'speak';
    
    switch (action) {
      case 'speak':
        await _voiceEngine.speak(params['text'] ?? '');
        break;
      case 'listen':
        final result = await _voiceEngine.listen();
        if (result != null) {
          _sendResult(command.id, {'transcript': result});
        }
        break;
      case 'translate':
        final text = params['text'] ?? '';
        final targetLanguage = params['targetLanguage'] ?? 'en';
        final translation = await _voiceEngine.translate(text, targetLanguage);
        _sendResult(command.id, {'translation': translation});
        break;
      case 'analyze':
        final audioData = params['audioData'];
        final analysis = await _voiceEngine.analyzeAudio(audioData);
        _sendResult(command.id, analysis);
        break;
      default:
        throw Exception('Unknown voice action: $action');
    }
  }
  
  Future<void> _handleVisionCommand(Command command) async {
    final params = command.parameters;
    final action = params['action'] ?? 'capture';
    
    switch (action) {
      case 'capture':
        final imagePath = await _visionService.captureImage();
        _sendResult(command.id, {'imagePath': imagePath});
        break;
      case 'process':
        final imagePath = params['imagePath'] ?? '';
        final result = await _visionService.processImage(imagePath);
        _sendResult(command.id, result);
        break;
      case 'analyze':
        final imagePath = params['imagePath'] ?? '';
        final analysis = await _visionService.analyzeImage(imagePath);
        _sendResult(command.id, analysis);
        break;
      case 'detect':
        final imagePath = params['imagePath'] ?? '';
        final detections = await _visionService.detectObjects(imagePath);
        _sendResult(command.id, {'detections': detections});
        break;
      default:
        throw Exception('Unknown vision action: $action');
    }
  }
  
  Future<void> _handleCallCommand(Command command) async {
    final params = command.parameters;
    final action = params['action'] ?? 'make';
    
    switch (action) {
      case 'make':
        final phoneNumber = params['phoneNumber'] ?? '';
        final response = await _callService.makeCall(phoneNumber);
        _sendResult(command.id, response);
        break;
      case 'answer':
        await _callService.answerCall();
        _sendResult(command.id, {'status': 'answered'});
        break;
      case 'end':
        await _callService.endCall();
        _sendResult(command.id, {'status': 'ended'});
        break;
      case 'mute':
        await _callService.toggleMute();
        _sendResult(command.id, {'status': 'toggled'});
        break;
      case 'speaker':
        await _callService.toggleSpeaker();
        _sendResult(command.id, {'status': 'toggled'});
        break;
      default:
        throw Exception('Unknown call action: $action');
    }
  }
  
  Future<void> _handleSystemCommand(Command command) async {
    final params = command.parameters;
    final action = params['action'] ?? 'status';
    
    switch (action) {
      case 'status':
        final status = await _backgroundService.getSystemStatus();
        _sendResult(command.id, status);
        break;
      case 'start':
        await _backgroundService.startServices();
        _sendResult(command.id, {'status': 'started'});
        break;
      case 'stop':
        await _backgroundService.stopServices();
        _sendResult(command.id, {'status': 'stopped'});
        break;
      case 'restart':
        await _backgroundService.restartServices();
        _sendResult(command.id, {'status': 'restarted'});
        break;
      default:
        throw Exception('Unknown system action: $action');
    }
  }
  
  Future<void> _handleAutomationCommand(Command command) async {
    final params = command.parameters;
    final action = params['action'] ?? 'task';
    
    switch (action) {
      case 'task':
        final taskName = params['taskName'] ?? '';
        final result = await _backgroundService.executeTask(taskName, params);
        _sendResult(command.id, {'result': result});
        break;
      case 'schedule':
        final taskName = params['taskName'] ?? '';
        final schedule = params['schedule'] ?? {};
        await _backgroundService.scheduleTask(taskName, schedule);
        _sendResult(command.id, {'status': 'scheduled'});
        break;
      case 'cancel':
        final taskId = params['taskId'] ?? '';
        await _backgroundService.cancelTask(taskId);
        _sendResult(command.id, {'status': 'cancelled'});
        break;
      default:
        throw Exception('Unknown automation action: $action');
    }
  }
  
  void _sendCommandCompletion(String commandId, bool success, [String? error]) {
    _sendMessage({
      'type': 'command_complete',
      'commandId': commandId,
      'success': success,
      'error': error,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  void _sendResult(String commandId, Map<String, dynamic> data) {
    _sendMessage({
      'type': 'result',
      'commandId': commandId,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  void _processResponse(BrainResponse response) {
    // Handle response based on type
    Logger.info('Processing response: ${response.id}');
  }
  
  void _updateSystemState(Map<String, dynamic> data) {
    final appState = AppState();
    appState.updateMetric('system_state', data);
  }
  
  void _handleVoiceAnalysis(Map<String, dynamic> data) {
    Logger.debug('Voice analysis: $data');
  }
  
  void _handleVisionAnalysis(Map<String, dynamic> data) {
    Logger.debug('Vision analysis: $data');
  }
  
  void _handleCallEvent(Map<String, dynamic> data) {
    Logger.debug('Call event: $data');
  }
  
  Future<void> _syncSystemState() async {
    if (!_isConnected) return;
    
    try {
      final appState = AppState();
      final status = {
        'memory': appState.memoryUsage,
        'cpu': appState.cpuUsage,
        'battery': appState.batteryLevel,
        'isCharging': appState.isCharging,
        'tasks': {
          'total': appState.totalTasks,
          'completed': appState.completedTasks,
          'failed': appState.failedTasks,
          'successRate': appState.successRate,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _sendMessage({
        'type': 'state_sync',
        'data': status,
      });
    } catch (e) {
      Logger.error('State sync failed: $e');
    }
  }
  
  Future<void> processBackgroundTasks() async {
    try {
      // Process queued commands
      while (_commandQueue.isNotEmpty) {
        final command = _commandQueue.removeAt(0);
        await _processCommand(command);
      }
    } catch (e) {
      Logger.error('Background task processing failed: $e');
    }
  }
  
  // Public API
  Future<void> sendCommand(Map<String, dynamic> command) async {
    if (!_isConnected) {
      await connect();
    }
    
    final commandId = DateTime.now().millisecondsSinceEpoch.toString();
    command['id'] = commandId;
    command['timestamp'] = DateTime.now().toIso8601String();
    
    _sendMessage(command);
  }
  
  Future<BrainResponse?> sendCommandAndWait(
    Map<String, dynamic> command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_isConnected) {
      await connect();
    }
    
    final commandId = DateTime.now().millisecondsSinceEpoch.toString();
    command['id'] = commandId;
    command['timestamp'] = DateTime.now().toIso8601String();
    
    final completer = Completer<BrainResponse?>();
    Timer? timer;
    
    // Setup timeout
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Command timed out'));
      }
    });
    
    // Listen for response
    final subscription = _subscription;
    if (subscription != null) {
      // We'll handle this in the message stream
    }
    
    // Send command
    _sendMessage(command);
    
    // Wait for response (handled by _handleResponse)
    // For now, return a placeholder
    timer.cancel();
    return BrainResponse(
      id: commandId,
      status: 'pending',
      data: {},
    );
  }
  
  // Cleanup
  void dispose() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _stateSyncTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close(status.normalClosure);
    super.dispose();
  }
}
