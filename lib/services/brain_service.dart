import 'package:synapse_ai/utils/logger.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_ai/services/background_service.dart';
import 'package:synapse_ai/services/accessibility_service.dart';
import 'package:synapse_ai/services/overlay_service.dart';
import 'package:synapse_ai/utils/logger.dart';
import 'package:synapse_ai/models/ai_response.dart';
import 'package:synapse_ai/models/system_status.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class VisionService {
  Future<bool> captureScreen() async => true;
  Future<String> analyzeScreen() async => 'Screen analyzed';
}

class BrainService extends ChangeNotifier {
  static final BrainService _instance = BrainService._internal();
  factory BrainService() => _instance;
  BrainService._internal();

  final BackgroundService _backgroundService = BackgroundService();
  final AccessibilityService _accessibilityService = AccessibilityService();
  final OverlayService _overlayService = OverlayService();
  final VisionService _visionService = VisionService();
  final Connectivity _connectivity = Connectivity();

  bool _isProcessing = false;
  bool _isListening = false;
  bool _isThinking = false;
  String _lastCommand = '';
  String _lastResponse = '';
  final List<Map<String, dynamic>> _conversationHistory = [];

  bool get isProcessing => _isProcessing;
  bool get isListening => _isListening;
  bool get isThinking => _isThinking;
  String get lastCommand => _lastCommand;
  String get lastResponse => _lastResponse;
  List<Map<String, dynamic>> get conversationHistory => List.unmodifiable(_conversationHistory);

  Future<void> initialize() async {
    try {
      Logger.info('Initializing BrainService...');
      await _backgroundService.initialize();
      Logger.info('BrainService initialized successfully');
    } catch (e, stackTrace) {
      Logger.error('BrainService initialization failed: $e', stackTrace);
      rethrow;
    }
  }

  Future<AIResponse> processCommand(String command, {Map<String, dynamic>? context}) async {
    _isProcessing = true;
    _isThinking = true;
    _lastCommand = command;
    notifyListeners();

    try {
      Logger.info('Processing command: $command');
      
      final timestamp = DateTime.now();
      _conversationHistory.add({
        'role': 'user',
        'content': command,
        'timestamp': timestamp.toIso8601String(),
      });

      await Future.delayed(const Duration(seconds: 1));

      final responseText = 'Command processed: $command';
      _lastResponse = responseText;

      _conversationHistory.add({
        'role': 'assistant',
        'content': responseText,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _isThinking = false;
      _isProcessing = false;
      notifyListeners();

      return AIResponse(
        success: true,
        message: responseText,
        data: {'command': command},
      );
    } catch (e, stackTrace) {
      _isThinking = false;
      _isProcessing = false;
      notifyListeners();
      Logger.error('Failed to process command: $e', stackTrace);
      return AIResponse(
        success: false,
        message: 'Error processing command: $e',
      );
    }
  }

  Future<void> checkConnectivity() async {
    final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    final bool isDisconnected = results.contains(ConnectivityResult.none);
    if (isDisconnected) {
      Logger.info('Device is offline');
    }
  }

  Future<void> clearHistory() async {
    _conversationHistory.clear();
    _lastCommand = '';
    _lastResponse = '';
    notifyListeners();
    Logger.info('Conversation history cleared');
  }

  void _sendResult(String commandId, dynamic response) {
    Logger.info('Result sent for command $commandId');
  }
}
