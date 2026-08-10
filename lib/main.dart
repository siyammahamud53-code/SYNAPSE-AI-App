import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

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
      setState(() {
        _currentUser = account;
      });
    });
    _googleSignIn.signInSilently();
  }

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      debugPrint("Sign in error: $error");
    }
  }

  Future<void> _handleSignOut() => _googleSignIn.disconnect();

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user != null) {
      return ChatScreen(
        userEmail: user.email,
        displayName: user.displayName ?? "User",
        photoUrl: user.photoUrl,
        onSignOut: _handleSignOut,
      );
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0A0E), Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.psychology, size: 100, color: Colors.cyanAccent),
                ),
                const SizedBox(height: 30),
                const Text(
                  'SYNAPSE AI CORE',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Multi-Modal Autonomous AI Engine',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 13),
                ),
                const SizedBox(height: 50),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 10,
                  ),
                  icon: const Icon(Icons.login, color: Colors.black),
                  label: const Text(
                    'Sign in with Google',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: _handleSignIn,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String userEmail;
  final String displayName;
  final String? photoUrl;
  final VoidCallback onSignOut;

  const ChatScreen({
    super.key,
    required this.userEmail,
    required this.displayName,
    this.photoUrl,
    required this.onSignOut,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  late FlutterTts _flutterTts;
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _autoSpeak = true;

  final String _baseUrl = 'https://synapse-ai-core.onrender.com';

  @override
  void initState() {
    super.initState();
    _initTts();
    _audioRecorder = AudioRecorder();
    _requestPermissions();
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("bn-BD");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.9);
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.camera,
    ].request();
  }

  Future<void> _speak(String text) async {
    if (_autoSpeak && text.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        String path = '${dir.path}/synapse_audio.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint("Audio Record Error: $e");
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        File audioFile = File(path);
        List<int> audioBytes = await audioFile.readAsBytes();
        String base64Audio = base64Encode(audioBytes);

        _sendMultiModalRequest(audioBase64: base64Audio);
      }
    } catch (e) {
      debugPrint("Stop Record Error: $e");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _sendMultiModalRequest({String? text, String? audioBase64, String? imageBase64}) async {
    if ((text == null || text.trim().isEmpty) && audioBase64 == null && imageBase64 == null) return;

    setState(() {
      _messages.add({
        'sender': 'user', 
        'text': text ?? (audioBase64 != null ? "🎤 [ভয়েস মেসেজ পাঠানো হয়েছে]" : "📷 [ইমেজ পাঠানো হয়েছে]")
      });
      _messages.add({'sender': 'ai', 'text': ''});
      _isLoading = true;
    });

    _controller.clear();
    final aiMessageIndex = _messages.length - 1;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userEmail.split('@')[0],
          'email': widget.userEmail,
          'display_name': widget.displayName,
          'message': text ?? '',
          'audio_base64': audioBase64,
          'image_base64': imageBase64,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String aiResponse = data['response'] ?? data['text_response'] ?? 'কোনো উত্তর পাওয়া যায়নি।';
        
        setState(() {
          _messages[aiMessageIndex]['text'] = aiResponse;
          _isLoading = false;
        });
        
        _speak(aiResponse);
      } else {
        setState(() {
          _messages[aiMessageIndex]['text'] = 'সার্ভার এরর: Code ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages[aiMessageIndex]['text'] = 'কানেকশন সমস্যা: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.cyanAccent.withOpacity(0.2),
              child: const Icon(Icons.bolt, color: Colors.cyanAccent),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.displayName, style: const TextStyle(fontSize: 16)),
                const Text('SYNAPSE CORE ONLINE', style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF12121A),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(_autoSpeak ? Icons.volume_up : Icons.volume_off, color: Colors.cyanAccent),
            onPressed: () {
              setState(() {
                _autoSpeak = !_autoSpeak;
              });
              if (!_autoSpeak) _flutterTts.stop();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(14.0),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? const Color(0xFF5A189A) : const Color(0xFF1E1E2A),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 0),
                          bottomRight: Radius.circular(isUser ? 0 : 16),
                        ),
                        border: Border.all(
                          color: isUser ? Colors.purpleAccent.withOpacity(0.5) : Colors.cyanAccent.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.3),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: LinearProgressIndicator(color: Colors.cyanAccent, backgroundColor: Color(0xFF1E1E2A)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            color: const Color(0xFF12121A),
            child: Row(
              children: [
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecordingAndSend(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.redAccent : Colors.cyanAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic : Icons.mic_none, 
                      color: _isRecording ? Colors.white : Colors.cyanAccent
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'SYNAPSE-কে বলুন বা লিখুন...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (val) => _sendMultiModalRequest(text: val),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.cyanAccent),
                  onPressed: () => _sendMultiModalRequest(text: _controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
