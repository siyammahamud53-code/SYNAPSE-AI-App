import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class CallLogger {
  static void info(String msg) => debugPrint('[INFO] $msg');
  static void warning(String msg) => debugPrint('[WARN] $msg');
  static void error(String msg, [dynamic stackTrace]) => debugPrint('[ERROR] $msg');
  static void debug(String msg) => debugPrint('[DEBUG] $msg');
}

class CallService extends ChangeNotifier {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();
  
  final MethodChannel _nativeChannel = const MethodChannel('com.synapse.ai/native');
  final MethodChannel _callChannel = const MethodChannel('com.synapse.ai/call');
  
  bool _isInitialized = false;
  bool _isCallActive = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCallRecording = false;
  
  String _currentCallNumber = '';
  String _currentCallState = 'idle';
  String _lastCallNumber = '';
  DateTime? _callStartTime;
  DateTime? _callEndTime;
  
  int _callDuration = 0;
  final List<Map<String, dynamic>> _callHistory = [];
  
  bool get isCallActive => _isCallActive;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isCallRecording => _isCallRecording;
  String get currentCallNumber => _currentCallNumber;
  String get currentCallState => _currentCallState;
  int get callDuration => _callDuration;
  List<Map<String, dynamic>> get callHistory => _callHistory;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      CallLogger.info('Initializing CallService...');
      await _requestPermissions();
      
      PhoneState.stream.listen((PhoneState event) {
        _handlePhoneStateChange(event);
      });
      
      _callChannel.setMethodCallHandler(_handleCallMethodCall);
      
      _isInitialized = true;
      CallLogger.info('CallService initialized successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      CallLogger.error('CallService initialization failed: $e', stackTrace);
      rethrow;
    }
  }
  
  Future<void> _requestPermissions() async {
    try {
      final permissions = [
        Permission.phone,
        Permission.microphone,
        Permission.storage,
      ];
      
      final statuses = await permissions.request();
      
      if (statuses[Permission.phone] != PermissionStatus.granted) {
        CallLogger.warning('Phone permission not granted');
      }
      
      if (statuses[Permission.microphone] != PermissionStatus.granted) {
        CallLogger.warning('Microphone permission not granted');
      }
    } catch (e) {
      CallLogger.error('Permission request failed: $e');
    }
  }
  
  void _handlePhoneStateChange(PhoneState event) {
    CallLogger.debug('Phone state changed: ${event.status}');
    
    switch (event.status) {
      case PhoneStateStatus.NOTHING:
        _handleCallIdle();
        break;
      case PhoneStateStatus.CALL_INCOMING:
        _handleCallRinging(event);
        break;
      case PhoneStateStatus.CALL_STARTED:
      case PhoneStateStatus.CALL_ENDED:
        _handleCallOffhook(event);
        break;
      default:
        break;
    }
    
    _currentCallState = event.status.toString();
    notifyListeners();
  }
  
  void _handleCallIdle() {
    if (_isCallActive) {
      _isCallActive = false;
      _callEndTime = DateTime.now();
      _callDuration = _callStartTime != null ? _callEndTime!.difference(_callStartTime!).inSeconds : 0;
      
      _addToHistory(
        number: _currentCallNumber,
        duration: _callDuration,
        type: 'outgoing',
        startTime: _callStartTime ?? DateTime.now(),
        endTime: _callEndTime!,
      );
      
      _currentCallNumber = '';
      _callStartTime = null;
      
      CallLogger.info('Call ended');
      notifyListeners();
    }
  }
  
  void _handleCallRinging(PhoneState event) {
    _isCallActive = true;
    _currentCallNumber = event.number ?? 'Unknown';
    _callStartTime = DateTime.now();
    
    CallLogger.info('Incoming call from: $_currentCallNumber');
    notifyListeners();
  }
  
  void _handleCallOffhook(PhoneState event) {
    if (!_isCallActive) {
      _isCallActive = true;
      _currentCallNumber = event.number ?? 'Unknown';
      _callStartTime = DateTime.now();
      
      CallLogger.info('Outgoing call to: $_currentCallNumber');
      notifyListeners();
    }
  }
  
  void _addToHistory({
    required String number,
    required int duration,
    required String type,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final entry = {
      'number': number,
      'duration': duration,
      'type': type,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
    
    _callHistory.insert(0, entry);
    if (_callHistory.length > 100) {
      _callHistory.removeLast();
    }
  }
  
  Future<dynamic> _handleCallMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCallStateChanged':
        final state = call.arguments['state'];
        final number = call.arguments['number'];
        _handleNativeCallState(state, number);
        break;
      default:
        throw PlatformException(
          code: 'NOT_IMPLEMENTED',
          message: 'Method not implemented',
        );
    }
  }
  
  void _handleNativeCallState(String state, String? number) {
    CallLogger.debug('Native call state: $state, Number: $number');
    
    switch (state) {
      case 'idle':
        _handleCallIdle();
        break;
      case 'ringing':
        _currentCallNumber = number ?? 'Unknown';
        _isCallActive = true;
        _callStartTime = DateTime.now();
        notifyListeners();
        break;
      case 'offhook':
        _isCallActive = true;
        _currentCallNumber = number ?? 'Unknown';
        _callStartTime ??= DateTime.now();
        notifyListeners();
        break;
      default:
        break;
    }
  }
  
  Future<void> makeCall(String phoneNumber) async {
    try {
      CallLogger.info('Making call to: $phoneNumber');
      
      if (phoneNumber.isEmpty) {
        throw Exception('Phone number cannot be empty');
      }
      
      final canCall = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      if (canCall == true) {
        _currentCallNumber = phoneNumber;
        _lastCallNumber = phoneNumber;
        _isCallActive = true;
        _callStartTime = DateTime.now();
        
        CallLogger.info('Call initiated to: $phoneNumber');
        notifyListeners();
      } else {
        throw Exception('Failed to make call');
      }
    } catch (e) {
      CallLogger.error('Failed to make call: $e');
      rethrow;
    }
  }
  
  Future<void> answerCall() async {
    try {
      CallLogger.info('Answering call');
      final result = await _nativeChannel.invokeMethod('answerCall');
      
      if (result == true) {
        _isCallActive = true;
        _callStartTime = DateTime.now();
        CallLogger.info('Call answered');
        notifyListeners();
      } else {
        throw Exception('Failed to answer call');
      }
    } catch (e) {
      CallLogger.error('Failed to answer call: $e');
      rethrow;
    }
  }
  
  Future<void> endCall() async {
    try {
      CallLogger.info('Ending call');
      final result = await _nativeChannel.invokeMethod('endCall');
      
      if (result == true) {
        _isCallActive = false;
        _callEndTime = DateTime.now();
        _callDuration = _callStartTime != null ? _callEndTime!.difference(_callStartTime!).inSeconds : 0;
        
        _addToHistory(
          number: _currentCallNumber,
          duration: _callDuration,
          type: 'outgoing',
          startTime: _callStartTime ?? DateTime.now(),
          endTime: _callEndTime!,
        );
        
        _currentCallNumber = '';
        _callStartTime = null;
        
        CallLogger.info('Call ended');
        notifyListeners();
      } else {
        throw Exception('Failed to end call');
      }
    } catch (e) {
      CallLogger.error('Failed to end call: $e');
      rethrow;
    }
  }
  
  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      final result = await _nativeChannel.invokeMethod('toggleMute', {'mute': _isMuted});
      
      if (result != true) {
        _isMuted = !_isMuted;
        throw Exception('Failed to toggle mute');
      }
      
      CallLogger.info('Mute toggled: ${_isMuted ? 'on' : 'off'}');
      notifyListeners();
    } catch (e) {
      CallLogger.error('Failed to toggle mute: $e');
      rethrow;
    }
  }
  
  Future<void> toggleSpeaker() async {
    try {
      _isSpeakerOn = !_isSpeakerOn;
      final result = await _nativeChannel.invokeMethod('toggleSpeaker', {'speaker': _isSpeakerOn});
      
      if (result != true) {
        _isSpeakerOn = !_isSpeakerOn;
        throw Exception('Failed to toggle speaker');
      }
      
      CallLogger.info('Speaker toggled: ${_isSpeakerOn ? 'on' : 'off'}');
      notifyListeners();
    } catch (e) {
      CallLogger.error('Failed to toggle speaker: $e');
      rethrow;
    }
  }
  
  Future<void> startRecording() async {
    try {
      if (_isCallRecording) return;
      _isCallRecording = true;
      
      final result = await _nativeChannel.invokeMethod('startCallRecording');
      if (result != true) {
        _isCallRecording = false;
        throw Exception('Failed to start recording');
      }
      
      CallLogger.info('Call recording started');
      notifyListeners();
    } catch (e) {
      CallLogger.error('Failed to start recording: $e');
      rethrow;
    }
  }
  
  Future<void> stopRecording() async {
    try {
      if (!_isCallRecording) return;
      _isCallRecording = false;
      
      final result = await _nativeChannel.invokeMethod('stopCallRecording');
      if (result != true) {
        _isCallRecording = true;
        throw Exception('Failed to stop recording');
      }
      
      CallLogger.info('Call recording stopped');
      notifyListeners();
    } catch (e) {
      CallLogger.error('Failed to stop recording: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> getCurrentCallInfo() async {
    return {
      'active': _isCallActive,
      'number': _currentCallNumber,
      'state': _currentCallState,
      'duration': _callDuration,
      'muted': _isMuted,
      'speaker': _isSpeakerOn,
      'recording': _isCallRecording,
      'startTime': _callStartTime?.toIso8601String(),
    };
  }
  
  Future<List<Map<String, dynamic>>> getCallHistory() async {
    return _callHistory;
  }
  
  void clearCallHistory() {
    _callHistory.clear();
    notifyListeners();
  }
}
