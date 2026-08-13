// ============================================================
// SYNAPSE AI - Flutter Mobile Client
// Complete Production-Ready Implementation
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:text_to_speech/text_to_speech.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';

// ============================================================
// CONFIGURATION
// ============================================================
class AppConfig {
  static const String baseUrl = 
      'https://siyammahamud53-synapse-ai-core.hf.space';
  static const String apiKey = 'fallback-key-change-me';
  static const String wsEndpoint = 
      'wss://siyammahamud53-synapse-ai-core.hf.space/ws/chat';
  
  // Timeouts
  static const Duration restTimeout = Duration(seconds: 10);
  static const Duration wsPingInterval = Duration(seconds: 10);
  static const Duration wsReconnectDelay = Duration(seconds: 2);
}

// ============================================================
// THEME
// ============================================================
class AppTheme {
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5A52D5);
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF2A2A4A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C0);
  static const Color accent = Color(0xFF00D4FF);
  static const Color success = Color(0xFF00FF88);
  static const Color error = Color(0xFFFF4466);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: surface,
      background: background,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardTheme(
      color: surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: textSecondary),
    ),
  );
}

// ============================================================
// MODELS
// ============================================================
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final double confidence;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.confidence = 0.0,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'confidence': confidence,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'],
    isUser: json['isUser'],
    timestamp: DateTime.parse(json['timestamp']),
    confidence: json['confidence'] ?? 0.0,
  );
}

class GameAction {
  final String type;
  final double? x;
  final double? y;
  final double pressure;
  final double timestamp;

  GameAction({
    required this.type,
    this.x,
    this.y,
    this.pressure = 0.5,
    double? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch / 1000;

  Map<String, dynamic> toJson() => {
    'type': 'game_action',
    'action_type': type,
    'x': x,
    'y': y,
    'pressure': pressure,
    'timestamp': timestamp,
  };
}

// ============================================================
// MAIN APP
// ============================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SYNAPSE AI',
      theme: AppTheme.darkTheme,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // Core Services
  late TabController _tabController;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TTS _tts = TTS();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // AI Communication
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  WebSocketChannel? _wsChannel;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isProcessing = false;
  Timer? _wsPingTimer;
  Timer? _wsReconnectTimer;

  // Game Mode
  bool _gameModeActive = false;
  final List<GameAction> _gameActions = [];
  double _gameLatency = 0.0;

  // State
  bool _isListening = false;
  bool _isSpeaking = false;
  String _connectionStatus = 'Disconnected';

  // ============================================================
  // INIT
  // ============================================================
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSpeech();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputController.dispose();
    _wsPingTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  // ============================================================
  // SPEECH INIT
  // ============================================================
  void _initSpeech() async {
    try {
      await _speech.initialize(
        onStatus: (status) {
          setState(() {
            _isListening = status == 'listening';
          });
        },
      );
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  // ============================================================
  // WEBSOCKET CONNECTION
  // ============================================================
  void _connectWebSocket() {
    if (_isConnecting || _isConnected) return;
    
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Connecting...';
    });

    try {
      final wsUrl = Uri.parse(
        '${AppConfig.wsEndpoint}?api_key=${AppConfig.apiKey}'
      );
      
      _wsChannel = IOWebSocketChannel.connect(wsUrl);
      
      _wsChannel!.stream.listen(
        _onWebSocketMessage,
        onError: _onWebSocketError,
        onDone: _onWebSocketDone,
      );
      
      // Start ping timer
      _wsPingTimer = Timer.periodic(
        AppConfig.wsPingInterval,
        (_) => _sendPing(),
      );
      
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      setState(() {
        _isConnecting = false;
        _connectionStatus = 'Error: ${e.toString()}';
      });
      _scheduleReconnect();
    }
  }

  void _onWebSocketMessage(dynamic data) {
    try {
      final message = jsonDecode(data);
      final type = message['type'] as String?;
      
      switch (type) {
        case 'connected':
          setState(() {
            _isConnected = true;
            _isConnecting = false;
            _connectionStatus = 'Connected ✅';
          });
          _addSystemMessage('Connected to SYNAPSE AI');
          break;
          
        case 'chat_response':
          final text = message['message'] as String? ?? '';
          final confidence = (message['confidence'] as num?)?.toDouble() ?? 0.0;
          _addAiMessage(text, confidence);
          _speakText(text);
          break;
          
        case 'game_response':
          final actionData = message['action'] as Map<String, dynamic>?;
          if (actionData != null) {
            final predictedAction = actionData['predicted_action'] as String?;
            final confidence = (actionData['confidence'] as num?)?.toDouble() ?? 0.0;
            _handleGameResponse(predictedAction, confidence);
          }
          break;
          
        case 'pong':
          // Calculate latency
          final serverTimestamp = (message['timestamp'] as num?)?.toDouble() ?? 0.0;
          final latency = (DateTime.now().millisecondsSinceEpoch / 1000) - serverTimestamp;
          setState(() {
            _gameLatency = latency * 1000; // Convert to ms
          });
          break;
          
        case 'error':
          final errorMsg = message['message'] as String? ?? 'Unknown error';
          _addSystemMessage('⚠️ Error: $errorMsg');
          break;
          
        default:
          // Handle unknown message type
          break;
      }
    } catch (e) {
      debugPrint('WebSocket message parse error: $e');
    }
  }

  void _onWebSocketError(dynamic error) {
    debugPrint('WebSocket error: $error');
    setState(() {
      _isConnected = false;
      _connectionStatus = 'Error: $error';
    });
    _scheduleReconnect();
  }

  void _onWebSocketDone() {
    debugPrint('WebSocket disconnected');
    setState(() {
      _isConnected = false;
      _connectionStatus = 'Disconnected';
    });
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(AppConfig.wsReconnectDelay, () {
      if (!_isConnected) {
        _connectWebSocket();
      }
    });
  }

  void _sendWebSocketMessage(Map<String, dynamic> message) {
    if (_wsChannel != null && _isConnected) {
      try {
        _wsChannel!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('WebSocket send error: $e');
      }
    } else {
      _addSystemMessage('⚠️ Not connected to server. Reconnecting...');
      _connectWebSocket();
    }
  }

  void _sendPing() {
    if (_isConnected) {
      _sendWebSocketMessage({'type': 'ping'});
    }
  }

  // ============================================================
  // MESSAGE HANDLING
  // ============================================================
  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    _addMessage(ChatMessage(text: text, isUser: true));
  }

  void _addAiMessage(String text, double confidence) {
    _addMessage(ChatMessage(text: text, isUser: false, confidence: confidence));
  }

  void _addSystemMessage(String text) {
    _addMessage(ChatMessage(text: '🔷 $text', isUser: false, confidence: 1.0));
  }

  void _scrollToBottom() {
    // Scroll logic would be implemented with a ScrollController
  }

  // ============================================================
  // REST FALLBACK
  // ============================================================
  Future<void> _sendRestMessage(String text) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    _addUserMessage(text);
    _inputController.clear();
    
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/chat'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': AppConfig.apiKey,
        },
        body: jsonEncode({
          'message': text,
          'session_id': DateTime.now().millisecondsSinceEpoch.toString(),
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      ).timeout(AppConfig.restTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message = data['message'] as String? ?? 'No response';
        final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
        _addAiMessage(message, confidence);
        _speakText(message);
      } else {
        _addSystemMessage('⚠️ REST Error: ${response.statusCode}');
      }
      
    } catch (e) {
      _addSystemMessage('⚠️ Error: ${e.toString()}');
      
      // Try WebSocket fallback
      if (_isConnected) {
        _sendWebSocketMessage({
          'type': 'chat',
          'text': text,
        });
      }
      
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // ============================================================
  // GAME MODE
  // ============================================================
  void _toggleGameMode() {
    setState(() {
      _gameModeActive = !_gameModeActive;
      if (_gameModeActive) {
        _addSystemMessage('🎮 Game Mode ACTIVATED');
        _addSystemMessage('📡 Latency: ${_gameLatency.toStringAsFixed(1)}ms');
      } else {
        _addSystemMessage('🎮 Game Mode DEACTIVATED');
      }
    });
  }

  void _sendGameAction(String type, {double? x, double? y, double pressure = 0.5}) {
    if (!_gameModeActive || !_isConnected) {
      _addSystemMessage('⚠️ Game mode not active or not connected');
      return;
    }

    final action = GameAction(
      type: type,
      x: x,
      y: y,
      pressure: pressure,
    );
    
    _gameActions.add(action);
    
    // Send via WebSocket
    _sendWebSocketMessage(action.toJson());
    
    // Update UI
    setState(() {
      _gameLatency = 0.0; // Will be updated by server response
    });
  }

  void _handleGameResponse(String? predictedAction, double confidence) {
    // Handle AI prediction for game
    debugPrint('🎮 AI Predicted: $predictedAction (${(confidence * 100).toStringAsFixed(1)}%)');
  }

  // ============================================================
  // VOICE & TTS
  // ============================================================
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
    } else {
      try {
        await _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              final text = result.recognizedWords;
              if (text.isNotEmpty) {
                _inputController.text = text;
                _sendMessage();
              }
            }
          },
          listenOptions: stt.SpeechToTextListenOptions(
            listenMode: stt.ListenMode.dictation,
          ),
        );
        setState(() {
          _isListening = true;
        });
      } catch (e) {
        debugPrint('Speech listen error: $e');
      }
    }
  }

  Future<void> _speakText(String text) async {
    try {
      setState(() {
        _isSpeaking = true;
      });
      await _tts.speak(text);
      setState(() {
        _isSpeaking = false;
      });
    } catch (e) {
      debugPrint('TTS error: $e');
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================
  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isProcessing) return;
    
    // Use WebSocket if connected, otherwise REST
    if (_isConnected) {
      _sendWebSocketMessage({
        'type': 'chat',
        'text': text,
      });
      _addUserMessage(text);
      _inputController.clear();
      
      // Add a temporary placeholder for AI response
      _addMessage(ChatMessage(text: '⏳ Thinking...', isUser: false));
    } else {
      _sendRestMessage(text);
    }
  }

  // ============================================================
  // UI BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Custom App Bar
          _buildAppBar(),
          
          // Connection Status
          _buildConnectionStatus(),
          
          // Tab Bar
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accent,
              labelColor: AppTheme.textPrimary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(icon: Icon(Icons.chat), text: 'Chat'),
                Tab(icon: Icon(Icons.games), text: 'Game Mode'),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab(),
                _buildGameTab(),
              ],
            ),
          ),
        ],
      ),
      
      // Floating Action Button for Voice
      floatingActionButton: _tabController.index == 0
          ? _buildVoiceButton()
          : _buildGameControlButton(),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'S',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SYNAPSE AI',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _connectionStatus,
                  style: TextStyle(
                    color: _isConnected ? AppTheme.success : AppTheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Google Sign In
          IconButton(
            icon: const Icon(Icons.account_circle, color: AppTheme.textSecondary),
            onPressed: _signInWithGoogle,
          ),
          
          // TTS Toggle
          IconButton(
            icon: Icon(
              _isSpeaking ? Icons.volume_up : Icons.volume_off,
              color: _isSpeaking ? AppTheme.accent : AppTheme.textSecondary,
            ),
            onPressed: () {
              if (!_isSpeaking) {
                // Read last AI message
                final lastAiMessage = _messages.where((m) => !m.isUser).lastOrNull;
                if (lastAiMessage != null) {
                  _speakText(lastAiMessage.text);
                }
              } else {
                _tts.stop();
                setState(() {
                  _isSpeaking = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONNECTION STATUS
  // ============================================================
  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _isConnected ? AppTheme.success.withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected ? AppTheme.success : AppTheme.error,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isConnected ? 'Connected to SYNAPSE AI' : 'Disconnected - Reconnecting...',
            style: TextStyle(
              color: _isConnected ? AppTheme.success : AppTheme.error,
              fontSize: 12,
            ),
          ),
          if (_gameModeActive && _isConnected) ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '🎮 ${_gameLatency.toStringAsFixed(0)}ms',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CHAT TAB
  // ============================================================
  Widget _buildChatTab() {
    return Column(
      children: [
        // Messages
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            reverse: true,
            itemCount: _messages.reversed.length,
            itemBuilder: (context, index) {
              final message = _messages.reversed.elementAt(index);
              return _buildChatBubble(message);
            },
          ),
        ),
        
        // Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              top: BorderSide(color: AppTheme.surfaceLight, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Input field
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: _isListening ? '🎤 Listening...' : 'Type a message...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isProcessing,
                ),
              ),
              const SizedBox(width: 8),
              
              // Send button
              CircleAvatar(
                backgroundColor: AppTheme.primary,
                radius: 24,
                child: IconButton(
                  icon: Icon(
                    _isProcessing ? Icons.hourglass_empty : Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _isProcessing ? null : _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CHAT BUBBLE
  // ============================================================
  Widget _buildChatBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? AppTheme.primary : AppTheme.surfaceLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: message.isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: message.isUser ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  if (message.confidence > 0 && !message.isUser) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified,
                          size: 12,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(message.confidence * 100).toStringAsFixed(0)}% confident',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // GAME MODE TAB
  // ============================================================
  Widget _buildGameTab() {
    return Column(
      children: [
        // Game Controls
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _gameModeActive ? Icons.games : Icons.games_outlined,
                        color: _gameModeActive ? AppTheme.success : AppTheme.textSecondary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _gameModeActive ? 'Game Mode ACTIVE' : 'Game Mode INACTIVE',
                        style: TextStyle(
                          color: _gameModeActive ? AppTheme.success : AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_gameModeActive && _isConnected) ...[
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '⚡ ${_gameLatency.toStringAsFixed(0)}ms',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Game Controls Grid
                if (_gameModeActive) ...[
                  _buildGameControls(),
                  const SizedBox(height: 24),
                  
                  // Action Log
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Action Log',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              reverse: true,
                              itemCount: _gameActions.length,
                              itemBuilder: (context, index) {
                                final action = _gameActions.reversed.elementAt(index);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '🎮 ${action.type}${action.x != null ? ' (${action.x!.toStringAsFixed(0)}, ${action.y!.toStringAsFixed(0)})' : ''}',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Control Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              top: BorderSide(color: AppTheme.surfaceLight, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Toggle Game Mode
              ElevatedButton.icon(
                onPressed: _toggleGameMode,
                icon: Icon(
                  _gameModeActive ? Icons.stop : Icons.play_arrow,
                  size: 16,
                ),
                label: Text(_gameModeActive ? 'Deactivate' : 'Activate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gameModeActive ? AppTheme.error : AppTheme.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              // Clear Actions
              if (_gameModeActive)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _gameActions.clear();
                    });
                  },
                  child: const Text(
                    'Clear Log',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GAME CONTROLS
  // ============================================================
  Widget _buildGameControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildGameButton('⬆️', 'move_up', () => _sendGameAction('move_up')),
              _buildGameButton('⬇️', 'move_down', () => _sendGameAction('move_down')),
              _buildGameButton('⬅️', 'move_left', () => _sendGameAction('move_left')),
              _buildGameButton('➡️', 'move_right', () => _sendGameAction('move_right')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildGameButton('🔫', 'shoot', () => _sendGameAction('shoot')),
              _buildGameButton('🔄', 'reload', () => _sendGameAction('reload')),
              _buildGameButton('🏃', 'sprint', () => _sendGameAction('sprint')),
              _buildGameButton('🛡️', 'defend', () => _sendGameAction('defend')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Custom action with coordinates
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Tap to aim: ',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    GestureDetector(
                      onTapDown: (details) {
                        final size = context.size;
                        if (size != null) {
                          final x = details.localPosition.dx / size.width;
                          final y = details.localPosition.dy / size.height;
                          _sendGameAction('aim', x: x, y: y);
                        }
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary),
                        ),
                        child: const Center(
                          child: Text(
                            '🎯',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GAME BUTTON
  // ============================================================
  Widget _buildGameButton(String label, String action, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VOICE BUTTON
  // ============================================================
  Widget _buildVoiceButton() {
    return FloatingActionButton(
      backgroundColor: _isListening ? AppTheme.error : AppTheme.primary,
      onPressed: _toggleListening,
      child: Icon(
        _isListening ? Icons.mic : Icons.mic_none,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  // ============================================================
  // GAME CONTROL BUTTON
  // ============================================================
  Widget _buildGameControlButton() {
    return FloatingActionButton(
      backgroundColor: _gameModeActive ? AppTheme.error : AppTheme.primary,
      onPressed: _toggleGameMode,
      child: Icon(
        _gameModeActive ? Icons.stop : Icons.games,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================
  Future<void> _signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _addSystemMessage('✅ Signed in as ${account.displayName}');
      }
    } catch (e) {
      _addSystemMessage('⚠️ Sign in error: $e');
    }
  }
}
