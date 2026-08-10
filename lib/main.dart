import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; // নতুন প্যাকেজ

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SynapseApp());
}

class SynapseApp extends StatelessWidget {
  const SynapseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SYNAPSE AI Core',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0E),
        primaryColor: Colors.deepPurpleAccent,
      ),
      home: const AuthGate(),
    );
  }
}

// ... AuthGate ক্লাস আগের মতোই থাকবে ...
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  GoogleSignInAccount? _currentUser;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() => _currentUser = account);
    });
    _googleSignIn.signInSilently();
  }

  Future<void> _handleSignIn() async => await _googleSignIn.signIn();
  Future<void> _handleSignOut() => _googleSignIn.disconnect();

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user != null) {
      return ChatScreen(userEmail: user.email, displayName: user.displayName ?? "User", onSignOut: _handleSignOut);
    }
    // ... UI আগের মতোই ...
    return Scaffold(
      body: Center(child: ElevatedButton(onPressed: _handleSignIn, child: const Text('Sign in with Google'))),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String userEmail;
  final String displayName;
  final VoidCallback onSignOut;
  const ChatScreen({super.key, required this.userEmail, required this.displayName, required this.onSignOut});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  
  late FlutterTts _flutterTts;
  late AudioRecorder _audioRecorder;
  WebSocketChannel? _channel; // WebSocket চ্যানেল
  bool _isRecording = false;

  final String _wsUrl = 'wss://synapse-ai-core.onrender.com/ws/chat'; // WebSocket URL

  @override
  void initState() {
    super.initState();
    _initTts();
    _audioRecorder = AudioRecorder();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel!.stream.listen((message) {
        final data = jsonDecode(message);
        setState(() {
          _messages.add({'sender': 'ai', 'text': data['response']});
        });
        _speak(data['response']);
      });
    } catch (e) {
      debugPrint("WebSocket Error: $e");
    }
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("bn-BD");
  }

  Future<void> _speak(String text) async => await _flutterTts.speak(text);

  // অতি দ্রুত গতির সেন্ডিং (WebSocket ব্যবহার করে)
  void _sendFastMessage(String text) {
    if (text.isEmpty) return;
    setState(() => _messages.add({'sender': 'user', 'text': text}));
    _channel?.sink.add(jsonEncode({
      'user_id': widget.userEmail.split('@')[0],
      'message': text,
    }));
    _controller.clear();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _audioRecorder.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... UI আগের মতোই, শুধু send বাটনে _sendFastMessage কল করবি ...
    return Scaffold(
      appBar: AppBar(title: const Text("SYNAPSE FAST-CORE")),
      body: Column(
        children: [
          Expanded(child: ListView.builder(
            itemCount: _messages.length,
            itemBuilder: (context, index) => ListTile(title: Text(_messages[index]['text']!)),
          )),
          TextField(controller: _controller, onSubmitted: _sendFastMessage),
        ],
      ),
    );
  }
}
