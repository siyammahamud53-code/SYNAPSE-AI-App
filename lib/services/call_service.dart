import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:synapse_ai/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

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
  List<Map<String, dynamic>> _callHistory = [];
  
  // Getters
  bool get isCallActive => _isCallActive;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isCallRecording => _isCallRecording;
  String get currentCallNumber => _currentCallNumber;
  String get currentCallState => _currentCallState;
  int get callDuration => _callDuration;
  List<Map<String, dynamic>> get callHistory => _callHistory;
  
  // Initialization
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Logger.info('Initializing CallService...');
      
      // Request phone permissions
      await _requestPermissions();
      
      // Listen for phone state changes
      PhoneState.instance.stream.listen((PhoneStateEvent event) {
        _handlePhoneStateChange(event);
      });
      
      // Setup call channel handler
      _callChannel.setMethodCallHandler(_handleCallMethodCall);
      
      _isInitialized = true;
      Logger.info('CallService initialized successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      Logger.error('CallService initialization failed: $e', stackTrace);
      rethrow;
    }
  }
  
  Future<void> _requestPermissions() async {
    try {
      final permissions = [
        Permission.phone,
        Permission.microphone,
        Permission.manageExternalStorage,
      ];
      
      final statuses = await permissions.request();
      
      if (statuses[Permission.phone] != PermissionStatus.granted) {
        Logger.warning('Phone permission not granted');
      }
      
      if (statuses[Permission.microphone] != PermissionStatus.granted) {
        Logger.warning('Microphone permission not granted');
      }
    } catch (e) {
      Logger.error('Permission request failed: $e');
    }
  }
  
  void _handlePhoneStateChange(PhoneStateEvent event) {
    Logger.debug('Phone state changed: ${event.state}');
    
    switch (event.state) {
      case PhoneState.IDLE:
        _handleCallIdle();
        break;
      case PhoneState.RINGING:
        _handleCallRinging(event);
        break;
      case PhoneState.OFFHOOK:
        _handleCallOffhook(event);
        break;
      case PhoneState.STATE_NULL:
        _handleCallNull();
        break;
      default:
        break;
    }
    
    // Update state
    _currentCallState = event.state;
    notifyListeners();
  }
  
  void _handleCallIdle() {
    if (_isCallActive) {
      _isCallActive = false;
      _callEndTime = DateTime.now();
      _callDuration = _callEndTime!.difference(_callStartTime!).inSeconds;
      
      // Save to history
      _addToHistory(
        number: _currentCallNumber,
        duration: _callDuration,
        type: 'outgoing',
        startTime: _callStartTime!,
        endTime: _callEndTime!,
      );
      
      _currentCallNumber = '';
      _callStartTime = null;
      
      Logger.info('Call ended');
      notifyListeners();
    }
  }
  
  void _handleCallRinging(PhoneStateEvent event) {
    _isCallActive = true;
    _currentCallNumber = event.number ?? 'Unknown';
    _callStartTime = DateTime.now();
    
    Logger.info('Incoming call from: ${_currentCallNumber}');
    notifyListeners();
  }
  
  void _handleCallOffhook(PhoneStateEvent event) {
    if (!_isCallActive) {
      _isCallActive = true;
      _currentCallNumber = event.number ?? 'Unknown';
      _callStartTime = DateTime.now();
      
      Logger.info('Outgoing call to: ${_currentCallNumber}');
      notifyListeners();
    }
  }
  
  void _handleCallNull() {
    _isCallActive = false;
    _currentCallNumber = '';
    notifyListeners();
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
    Logger.debug('Native call state: $state, Number: $number');
    
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
        if (_callStartTime == null) {
          _callStartTime = DateTime.now();
        }
        notifyListeners();
        break;
      default:
        break;
    }
  }
  
  // Public API
  Future<void> makeCall(String phoneNumber) async {
    try {
      Logger.info('Making call to: $phoneNumber');
      
      // Validate phone number
      if (phoneNumber.isEmpty) {
        throw Exception('Phone number cannot be empty');
      }
      
      // Check if can make call
      final canCall = await FlutterPhoneDirectCaller.canCall(phoneNumber);
      if (!canCall) {
        throw Exception('Cannot make call to: $phoneNumber');
      }
      
      // Make call
      final result = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      if (result) {
        _currentCallNumber = phoneNumber;
        _lastCallNumber = phoneNumber;
        _isCallActive = true;
        _callStartTime = DateTime.now();
        
        Logger.info('Call initiated to: $phoneNumber');
        notifyListeners();
      } else {
        throw Exception('Failed to make call');
      }
    } catch (e) {
      Logger.error('Failed to make call: $e');
      rethrow;
    }
  }
  
  Future<void> answerCall() async {
    try {
      Logger.info('Answering call');
      
      // Use native method to answer call
      final result = await _nativeChannel.invokeMethod('answerCall');
      
      if (result == true) {
        _isCallActive = true;
        _callStartTime = DateTime.now();
        Logger.info('Call answered');
        notifyListeners();
      } else {
        throw Exception('Failed to answer call');
      }
    } catch (e) {
      Logger.error('Failed to answer call: $e');
      rethrow;
    }
  }
  
  Future<void> endCall() async {
    try {
      Logger.info('Ending call');
      
      // Use native method to end call
      final result = await _nativeChannel.invokeMethod('endCall');
      
      if (result == true) {
        _isCallActive = false;
        _callEndTime = DateTime.now();
        _callDuration = _callEndTime!.difference(_callStartTime!).inSeconds;
        
        // Save to history
        _addToHistory(
          number: _currentCallNumber,
          duration: _callDuration,
          type: 'outgoing',
          startTime: _callStartTime!,
          endTime: _callEndTime!,
        );
        
        _currentCallNumber = '';
        _callStartTime = null;
        
        Logger.info('Call ended');
        notifyListeners();
      } else {
        throw Exception('Failed to end call');
      }
    } catch (e) {
      Logger.error('Failed to end call: $e');
      rethrow;
    }
  }
  
  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      
      // Use native method to toggle mute
      final result = await _nativeChannel.invokeMethod('toggleMute', {
        'mute': _isMuted,
      });
      
      if (result != true) {
        _isMuted = !_isMuted;
        throw Exception('Failed to toggle mute');
      }
      
      Logger.info('Mute toggled: ${_isMuted ? 'on' : 'off'}');
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to toggle mute: $e');
      rethrow;
    }
  }
  
  Future<void> toggleSpeaker() async {
    try {
      _isSpeakerOn = !_isSpeakerOn;
      
      // Use native method to toggle speaker
      final result = await _nativeChannel.invokeMethod('toggleSpeaker', {
        'speaker': _isSpeakerOn,
      });
      
      if (result != true) {
        _isSpeakerOn = !_isSpeakerOn;
        throw Exception('Failed to toggle speaker');
      }
      
      Logger.info('Speaker toggled: ${_isSpeakerOn ? 'on' : 'off'}');
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to toggle speaker: $e');
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
      
      Logger.info('Call recording started');
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to start recording: $e');
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
      
      Logger.info('Call recording stopped');
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to stop recording: $e');
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
  
  // Cleanup
  void dispose() {
    super.dispose();
  }
}
