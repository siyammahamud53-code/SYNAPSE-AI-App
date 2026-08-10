import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

void main() {
  runApp(const SynapseApp());
}

class SynapseApp extends StatelessWidget {
  const SynapseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SYNAPSE AI Core Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepPurple,
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, size: 90, color: Colors.deepPurpleAccent),
              const SizedBox(height: 20),
              const Text(
                'SYNAPSE AI CORE',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 10),
              const Text(
                'Universal Intelligent Assistant Bridge',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                icon: const Icon(Icons.login, color: Colors.black),
                label: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _handleSignIn,
              ),
            ],
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

  final String _baseUrl = 'https://synapse-ai-core.onrender.com';

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
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
          'message': text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _messages[aiMessageIndex]['text'] = data['response'] ?? 'কোনো উত্তর পাওয়া যায়নি।';
          _isLoading = false;
        });
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.displayName),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        actions: [
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
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.deepPurple : const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        msg['text'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 14.0),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Colors.deepPurpleAccent),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'SYNAPSE-কে প্রশ্ন করুন...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurpleAccent),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
